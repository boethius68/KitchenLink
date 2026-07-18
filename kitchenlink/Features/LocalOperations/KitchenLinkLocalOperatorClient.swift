import Foundation

struct KitchenLinkLocalOperatorWireLine: Codable, Equatable {
    let itemID: String
    let name: String
    let quantity: Int
    let unitPriceMinor: Int
    let lineTotalMinor: Int
}

struct KitchenLinkLocalOperatorWireOrder: Codable, Equatable {
    let id: String
    let localSequence: Int64
    let createdAtMs: Int64
    let venueID: String
    let currency: String
    let totalMinor: Int
    let lines: [KitchenLinkLocalOperatorWireLine]
    let status: String

    func liveOrder(venueName: String) -> LiveOrderMessage? {
        guard let lifecycleStatus = OrderLifecycleStatus(rawValue: status) else { return nil }
        return LiveOrderMessage(
            id: id,
            createdAt: Date(timeIntervalSince1970: TimeInterval(createdAtMs) / 1_000),
            sourceDevice: "Lokales Gast-WLAN · #\(localSequence)",
            venueID: venueID,
            venueName: venueName,
            serviceMode: .pickup,
            tableID: nil,
            tableLabel: nil,
            customerNote: "",
            items: lines.map { line in
                LiveOrderLine(
                    id: "\(id)-\(line.itemID)",
                    name: line.name,
                    quantity: line.quantity,
                    unitPriceCents: line.unitPriceMinor,
                    kind: .food
                )
            },
            totalCents: totalMinor,
            status: lifecycleStatus
        )
    }
}

struct KitchenLinkLocalOperatorStatusRequest: Codable, Equatable {
    let targetStatus: String
    let idempotencyKey: String
}

struct KitchenLinkLocalOperatorStatusReceipt: Codable, Equatable {
    let status: String
    let orderID: String
    let orderStatus: String
    let eventID: String
    let localSequence: Int64
    let replayed: Bool
    let persistence: String
}

struct KitchenLinkLocalOperatorAPIError: Codable, Error, Equatable {
    let error: String
    let message: String
}

protocol KitchenLinkLocalOperatorTransport {
    func loadOrders(baseURL: URL) async throws -> [KitchenLinkLocalOperatorWireOrder]
    func updateStatus(
        baseURL: URL,
        orderID: String,
        targetStatus: OrderLifecycleStatus
    ) async throws -> KitchenLinkLocalOperatorStatusReceipt
}

struct URLSessionKitchenLinkLocalOperatorTransport: KitchenLinkLocalOperatorTransport {
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func loadOrders(baseURL: URL) async throws -> [KitchenLinkLocalOperatorWireOrder] {
        let url = baseURL.appendingPathComponent("operator/orders")
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode([KitchenLinkLocalOperatorWireOrder].self, from: data)
    }

    func updateStatus(
        baseURL: URL,
        orderID: String,
        targetStatus: OrderLifecycleStatus
    ) async throws -> KitchenLinkLocalOperatorStatusReceipt {
        let url = baseURL
            .appendingPathComponent("operator/orders")
            .appendingPathComponent(orderID)
            .appendingPathComponent("status")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(
            KitchenLinkLocalOperatorStatusRequest(
                targetStatus: targetStatus.rawValue,
                idempotencyKey: "operator-status:\(orderID):\(targetStatus.rawValue)"
            )
        )
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(KitchenLinkLocalOperatorStatusReceipt.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            if let apiError = try? decoder.decode(KitchenLinkLocalOperatorAPIError.self, from: data) {
                throw apiError
            }
            throw URLError(.badServerResponse)
        }
    }
}

@MainActor
final class KitchenLinkLocalOperationsModel: ObservableObject {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case failed(String)
    }

    static let addressDefaultsKey = "kitchenlink.localOperatorHubURL.v1"
    static let sandboxHubAddress = "http://192.168.178.110:8080"

    @Published var hubAddress: String
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var orders: [LiveOrderMessage] = []
    @Published private(set) var isUpdatingOrder = false

    private let transport: any KitchenLinkLocalOperatorTransport
    private let defaults: UserDefaults
    private var pollingTask: Task<Void, Never>?
    private var activeBaseURL: URL?

    init(
        transport: any KitchenLinkLocalOperatorTransport = URLSessionKitchenLinkLocalOperatorTransport(),
        defaults: UserDefaults = .standard
    ) {
        self.transport = transport
        self.defaults = defaults
        self.hubAddress = defaults.string(forKey: Self.addressDefaultsKey) ?? Self.sandboxHubAddress
    }

    var isConnected: Bool {
        connectionState == .connected
    }

    var connectionDetail: String {
        switch connectionState {
        case .disconnected:
            return "Noch nicht mit dem lokalen Hub verbunden."
        case .connecting:
            return "Lokaler Hub wird gesucht …"
        case .connected:
            return "Live mit dem lokalen Event-Log verbunden."
        case .failed(let message):
            return message
        }
    }

    func normalizedHubURL() -> URL? {
        let trimmed = hubAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "http://\(trimmed)"
        guard let url = URL(string: candidate),
              url.scheme?.lowercased() == "http",
              url.host != nil else {
            return nil
        }
        return url
    }

    func connect() {
        guard let baseURL = normalizedHubURL() else {
            connectionState = .failed("Bitte eine gültige lokale HTTP-Adresse eingeben.")
            return
        }

        hubAddress = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        defaults.set(hubAddress, forKey: Self.addressDefaultsKey)
        connect(to: baseURL)
    }

    func connect(to baseURL: URL) {
        pollingTask?.cancel()
        activeBaseURL = baseURL
        connectionState = .connecting
        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refresh(baseURL: baseURL)
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
            }
        }
    }

    func disconnect() {
        pollingTask?.cancel()
        pollingTask = nil
        activeBaseURL = nil
        connectionState = .disconnected
    }

    func refresh() async {
        guard let baseURL = activeBaseURL ?? normalizedHubURL() else {
            connectionState = .failed("Bitte eine gültige lokale HTTP-Adresse eingeben.")
            return
        }
        await refresh(baseURL: baseURL)
    }

    func update(order: LiveOrderMessage, to targetStatus: OrderLifecycleStatus) async -> Bool {
        guard let baseURL = activeBaseURL ?? normalizedHubURL(),
              order.status.canTransition(to: targetStatus) else {
            return false
        }
        isUpdatingOrder = true
        defer { isUpdatingOrder = false }
        do {
            _ = try await transport.updateStatus(
                baseURL: baseURL,
                orderID: order.id,
                targetStatus: targetStatus
            )
            await refresh(baseURL: baseURL)
            return true
        } catch {
            connectionState = .failed(Self.message(for: error))
            return false
        }
    }

    private func refresh(baseURL: URL) async {
        do {
            let wireOrders = try await transport.loadOrders(baseURL: baseURL)
            orders = wireOrders.compactMap { $0.liveOrder(venueName: "KitchenLink Testküche") }
            connectionState = .connected
        } catch {
            connectionState = .failed(Self.message(for: error))
        }
    }

    private static func message(for error: Error) -> String {
        if let apiError = error as? KitchenLinkLocalOperatorAPIError {
            return apiError.message
        }
        if let urlError = error as? URLError, urlError.code == .timedOut {
            return "Der lokale Hub antwortet nicht. WLAN und Adresse prüfen."
        }
        return "Lokaler Hub nicht erreichbar: \(error.localizedDescription)"
    }
}
