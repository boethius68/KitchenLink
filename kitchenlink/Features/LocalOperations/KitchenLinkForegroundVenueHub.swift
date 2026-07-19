import Darwin
import Foundation
import KitchenLinkLocalGuestCore
import Network

struct KitchenLinkVenueHubEndpoint: Equatable, Sendable {
    let guestURL: URL
    let operatorURL: URL
    let port: UInt16
}

protocol KitchenLinkVenueHubServing: AnyObject {
    func start() async throws -> KitchenLinkVenueHubEndpoint
    func stop()
}

enum KitchenLinkVenueHubError: LocalizedError {
    case alreadyRunning
    case noWiFiAddress
    case noListeningPort
    case requestTooLarge
    case malformedRequest
    case listener(String)

    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "Der Venue-Hub läuft bereits."
        case .noWiFiAddress:
            return "Keine lokale WLAN-Adresse gefunden. Bitte WLAN prüfen."
        case .noListeningPort:
            return "Der lokale Port konnte nicht geöffnet werden."
        case .requestTooLarge:
            return "Die lokale Anfrage ist zu groß."
        case .malformedRequest:
            return "Die lokale HTTP-Anfrage ist ungültig."
        case .listener(let message):
            return "Der iPhone-Hub konnte nicht gestartet werden: \(message)"
        }
    }
}

struct KitchenLinkHTTPRequestParser {
    private static let headerDelimiter = Data("\r\n\r\n".utf8)
    static let maximumRequestBytes = 128 * 1024

    static func parseIfComplete(_ data: Data) throws -> HTTPRequest? {
        guard data.count <= maximumRequestBytes else {
            throw KitchenLinkVenueHubError.requestTooLarge
        }
        guard let headerRange = data.range(of: headerDelimiter) else {
            return nil
        }
        guard let headerText = String(data: data[..<headerRange.lowerBound], encoding: .utf8) else {
            throw KitchenLinkVenueHubError.malformedRequest
        }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            throw KitchenLinkVenueHubError.malformedRequest
        }
        let requestParts = requestLine.split(separator: " ")
        guard requestParts.count == 3,
              requestParts[2].hasPrefix("HTTP/1.") else {
            throw KitchenLinkVenueHubError.malformedRequest
        }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).lowercased()
            let value = String(line[line.index(after: colon)...])
                .trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }

        guard let contentLength = Int(headers["content-length"] ?? "0"),
              contentLength >= 0,
              contentLength <= 64 * 1024 else {
            throw KitchenLinkVenueHubError.malformedRequest
        }
        let bodyStart = headerRange.upperBound
        guard data.count >= bodyStart + contentLength else {
            return nil
        }

        return HTTPRequest(
            method: String(requestParts[0]),
            path: String(requestParts[1]),
            headers: headers,
            body: data.subdata(in: bodyStart..<(bodyStart + contentLength))
        )
    }
}

protocol KitchenLinkLocalAddressProviding: Sendable {
    func wifiIPv4Address() -> String?
}

struct KitchenLinkSystemLocalAddressProvider: KitchenLinkLocalAddressProviding {
    func wifiIPv4Address() -> String? {
        var firstAddress: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&firstAddress) == 0, let firstAddress else { return nil }
        defer { freeifaddrs(firstAddress) }

        var fallback: String?
        var interface = firstAddress
        while true {
            let value = interface.pointee
            if let address = value.ifa_addr,
               address.pointee.sa_family == UInt8(AF_INET),
               value.ifa_flags & UInt32(IFF_UP) != 0,
               value.ifa_flags & UInt32(IFF_LOOPBACK) == 0 {
                let name = String(cString: value.ifa_name)
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let result = getnameinfo(
                    address,
                    socklen_t(address.pointee.sa_len),
                    &host,
                    socklen_t(host.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )
                if result == 0 {
                    let candidate = String(cString: host)
                    if name == "en0" { return candidate }
                    if !name.hasPrefix("pdp_ip") { fallback = fallback ?? candidate }
                }
            }
            guard let next = value.ifa_next else { break }
            interface = next
        }
        return fallback
    }
}

final class KitchenLinkForegroundVenueHubServer: KitchenLinkVenueHubServing, @unchecked Sendable {
    private let router: HTTPRouter
    private let addressProvider: any KitchenLinkLocalAddressProviding
    private let queue = DispatchQueue(label: "sf.kitchenlink.foreground-venue-hub")
    private var listener: NWListener?
    private var startContinuation: CheckedContinuation<KitchenLinkVenueHubEndpoint, Error>?

    init(
        databaseURL: URL,
        indexHTML: Data,
        deviceID: String,
        addressProvider: any KitchenLinkLocalAddressProviding = KitchenLinkSystemLocalAddressProvider()
    ) throws {
        let service = try LocalGuestOrderService(
            databasePath: databaseURL.path,
            deviceID: deviceID
        )
        self.router = HTTPRouter(service: service, indexHTML: indexHTML)
        self.addressProvider = addressProvider
    }

    func start() async throws -> KitchenLinkVenueHubEndpoint {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                guard self.listener == nil else {
                    continuation.resume(throwing: KitchenLinkVenueHubError.alreadyRunning)
                    return
                }

                do {
                    let parameters = NWParameters.tcp
                    parameters.allowLocalEndpointReuse = true
                    parameters.includePeerToPeer = true
                    let listener = try NWListener(using: parameters, on: .any)
                    self.listener = listener
                    self.startContinuation = continuation
                    listener.service = NWListener.Service(
                        name: "KitchenLink Venue Hub",
                        type: "_kitchenlink-hub._tcp"
                    )
                    listener.stateUpdateHandler = { [weak self] state in
                        self?.handleListenerState(state)
                    }
                    listener.newConnectionHandler = { [weak self] connection in
                        self?.handle(connection)
                    }
                    listener.start(queue: self.queue)
                } catch {
                    self.listener = nil
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.listener?.cancel()
            self.listener = nil
            if let continuation = self.startContinuation {
                self.startContinuation = nil
                continuation.resume(throwing: CancellationError())
            }
        }
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            guard let continuation = startContinuation else { return }
            startContinuation = nil
            guard let port = listener?.port?.rawValue else {
                continuation.resume(throwing: KitchenLinkVenueHubError.noListeningPort)
                stop()
                return
            }
            guard let address = addressProvider.wifiIPv4Address(),
                  let guestURL = URL(string: "http://\(address):\(port)"),
                  let operatorURL = URL(string: "http://127.0.0.1:\(port)") else {
                continuation.resume(throwing: KitchenLinkVenueHubError.noWiFiAddress)
                stop()
                return
            }
            continuation.resume(
                returning: KitchenLinkVenueHubEndpoint(
                    guestURL: guestURL,
                    operatorURL: operatorURL,
                    port: port
                )
            )

        case .failed(let error):
            let continuation = startContinuation
            startContinuation = nil
            listener?.cancel()
            listener = nil
            continuation?.resume(throwing: KitchenLinkVenueHubError.listener(error.localizedDescription))

        case .cancelled:
            listener = nil

        case .setup, .waiting:
            break

        @unknown default:
            break
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(from: connection, accumulated: Data())
    }

    private func receive(from connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4_096) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }

            var requestData = accumulated
            if let data { requestData.append(data) }
            do {
                if let request = try KitchenLinkHTTPRequestParser.parseIfComplete(requestData) {
                    self.send(self.router.route(request), over: connection)
                } else if error != nil || isComplete {
                    self.sendBadRequest(over: connection)
                } else {
                    self.receive(from: connection, accumulated: requestData)
                }
            } catch {
                self.sendBadRequest(over: connection)
            }
        }
    }

    private func sendBadRequest(over connection: NWConnection) {
        send(
            HTTPResponse(
                status: 400,
                reason: "Bad Request",
                contentType: "application/json; charset=utf-8",
                body: Data("{\"error\":\"bad_request\",\"message\":\"Ungültige HTTP-Anfrage.\"}".utf8)
            ),
            over: connection
        )
    }

    private func send(_ response: HTTPResponse, over connection: NWConnection) {
        connection.send(content: response.encoded(), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

@MainActor
final class KitchenLinkVenueHubModel: ObservableObject {
    enum State: Equatable {
        case stopped
        case starting
        case running
        case failed(String)
    }

    @Published private(set) var state: State = .stopped
    @Published private(set) var endpoint: KitchenLinkVenueHubEndpoint?

    private let serverFactory: () throws -> any KitchenLinkVenueHubServing
    private var server: (any KitchenLinkVenueHubServing)?

    init() {
        self.serverFactory = { try KitchenLinkVenueHubModel.makeDefaultServer() }
    }

    init(serverFactory: @escaping () throws -> any KitchenLinkVenueHubServing) {
        self.serverFactory = serverFactory
    }

    var isRunning: Bool { state == .running }

    var statusDetail: String {
        switch state {
        case .stopped:
            return "Der iPhone-Hub ist gestoppt."
        case .starting:
            return "Lokaler Hub und Gastseite werden gestartet …"
        case .running:
            return "Dieses iPhone nimmt lokale Bestellungen dauerhaft im Event-Log an."
        case .failed(let message):
            return message
        }
    }

    func start() async -> KitchenLinkVenueHubEndpoint? {
        stop()
        state = .starting
        do {
            let server = try serverFactory()
            self.server = server
            let endpoint = try await server.start()
            guard self.server != nil else { return nil }
            self.endpoint = endpoint
            state = .running
            return endpoint
        } catch is CancellationError {
            if state == .starting { state = .stopped }
            return nil
        } catch {
            server?.stop()
            server = nil
            endpoint = nil
            state = .failed(error.localizedDescription)
            return nil
        }
    }

    func stop() {
        server?.stop()
        server = nil
        endpoint = nil
        state = .stopped
    }

    private static func makeDefaultServer() throws -> any KitchenLinkVenueHubServing {
        let fileManager = FileManager.default
        let baseDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = baseDirectory.appendingPathComponent("KitchenLinkVenueHub", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let defaults = UserDefaults.standard
        let deviceKey = "kitchenlink.venueHub.deviceID.v1"
        let deviceID: String
        if let saved = defaults.string(forKey: deviceKey) {
            deviceID = saved
        } else {
            deviceID = "ios-hub-\(UUID().uuidString.lowercased())"
            defaults.set(deviceID, forKey: deviceKey)
        }

        return try KitchenLinkForegroundVenueHubServer(
            databaseURL: directory.appendingPathComponent("events.sqlite"),
            indexHTML: LocalGuestResources.indexHTML(),
            deviceID: deviceID
        )
    }
}
