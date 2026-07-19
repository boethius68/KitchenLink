import Darwin
import Foundation
import KitchenLinkLocalGuestCore
import Network

struct KitchenLinkVenueHubEndpoint: Equatable, Sendable {
    let guestURL: URL?
    let operatorURL: URL
    let port: UInt16
}

enum KitchenLinkVenueHubServerEvent: Equatable, Sendable {
    case endpointChanged(KitchenLinkVenueHubEndpoint)
    case failed(String)
}

protocol KitchenLinkVenueHubServing: AnyObject {
    var events: AsyncStream<KitchenLinkVenueHubServerEvent> { get }
    func start() async throws -> KitchenLinkVenueHubEndpoint
    func stop()
}

enum KitchenLinkVenueHubError: LocalizedError {
    case alreadyRunning
    case noListeningPort
    case requestTooLarge
    case malformedRequest
    case listener(String)

    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "Der Venue-Hub läuft bereits."
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
                }
            }
            guard let next = value.ifa_next else { break }
            interface = next
        }
        return nil
    }
}

enum KitchenLinkVenueHubIdentity {
    static let defaultsKey = "kitchenlink.venueHub.deviceID.v1"

    static func deviceID(defaults: UserDefaults = .standard) -> String {
        if let saved = defaults.string(forKey: defaultsKey) {
            return saved
        }
        let deviceID = "ios-hub-\(UUID().uuidString.lowercased())"
        defaults.set(deviceID, forKey: defaultsKey)
        return deviceID
    }
}

final class KitchenLinkForegroundVenueHubServer: KitchenLinkVenueHubServing, @unchecked Sendable {
    private let router: HTTPRouter
    private let deviceID: String
    private let addressProvider: any KitchenLinkLocalAddressProviding
    private let addressPollInterval: TimeInterval
    private let queue = DispatchQueue(label: "sf.kitchenlink.foreground-venue-hub")
    private let eventContinuation: AsyncStream<KitchenLinkVenueHubServerEvent>.Continuation
    let events: AsyncStream<KitchenLinkVenueHubServerEvent>
    private var listener: NWListener?
    private var addressTimer: DispatchSourceTimer?
    private var bonjourService: NetService?
    private var currentEndpoint: KitchenLinkVenueHubEndpoint?
    private var startContinuation: CheckedContinuation<KitchenLinkVenueHubEndpoint, Error>?

    init(
        databaseURL: URL,
        indexHTML: Data,
        deviceID: String,
        addressProvider: any KitchenLinkLocalAddressProviding = KitchenLinkSystemLocalAddressProvider(),
        addressPollInterval: TimeInterval = 2
    ) throws {
        let eventStream = AsyncStream.makeStream(
            of: KitchenLinkVenueHubServerEvent.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        let service = try LocalGuestOrderService(
            databasePath: databaseURL.path,
            deviceID: deviceID
        )
        self.router = HTTPRouter(service: service, indexHTML: indexHTML)
        self.deviceID = deviceID
        self.addressProvider = addressProvider
        self.addressPollInterval = addressPollInterval
        self.events = eventStream.stream
        self.eventContinuation = eventStream.continuation
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
            self.stopAddressMonitoring()
            self.stopBonjourAdvertisement()
            self.listener?.cancel()
            self.listener = nil
            self.currentEndpoint = nil
            self.eventContinuation.finish()
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
            guard let endpoint = makeEndpoint(port: port) else {
                continuation.resume(throwing: KitchenLinkVenueHubError.noListeningPort)
                stop()
                return
            }
            currentEndpoint = endpoint
            publishBonjourAdvertisement(endpoint)
            startAddressMonitoring(port: port)
            continuation.resume(returning: endpoint)

        case .failed(let error):
            let continuation = startContinuation
            startContinuation = nil
            stopAddressMonitoring()
            stopBonjourAdvertisement()
            listener?.cancel()
            listener = nil
            let venueHubError = KitchenLinkVenueHubError.listener(error.localizedDescription)
            if let continuation {
                continuation.resume(throwing: venueHubError)
            } else {
                eventContinuation.yield(.failed(venueHubError.localizedDescription))
                eventContinuation.finish()
            }

        case .cancelled:
            stopAddressMonitoring()
            stopBonjourAdvertisement()
            listener = nil

        case .setup, .waiting:
            break

        @unknown default:
            break
        }
    }

    private func makeEndpoint(port: UInt16) -> KitchenLinkVenueHubEndpoint? {
        guard let operatorURL = URL(string: "http://127.0.0.1:\(port)") else { return nil }
        let guestURL = addressProvider.wifiIPv4Address()
            .flatMap { URL(string: "http://\($0):\(port)") }
        return KitchenLinkVenueHubEndpoint(
            guestURL: guestURL,
            operatorURL: operatorURL,
            port: port
        )
    }

    private func startAddressMonitoring(port: UInt16) {
        stopAddressMonitoring()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(
            deadline: .now() + addressPollInterval,
            repeating: addressPollInterval
        )
        timer.setEventHandler { [weak self] in
            guard let self,
                  let endpoint = self.makeEndpoint(port: port),
                  endpoint != self.currentEndpoint else { return }
            self.currentEndpoint = endpoint
            self.updateBonjourAdvertisement(endpoint)
            self.eventContinuation.yield(.endpointChanged(endpoint))
        }
        addressTimer = timer
        timer.resume()
    }

    private func stopAddressMonitoring() {
        addressTimer?.setEventHandler {}
        addressTimer?.cancel()
        addressTimer = nil
    }

    private func makeBonjourTXTRecord(baseURL: URL?) -> Data {
        let record = KitchenLinkVenueHubBonjourContract.record(
            hubID: deviceID,
            baseURL: baseURL,
            displayName: "KitchenLink iPhone Hub"
        ).mapValues { Data($0.utf8) }
        return NetService.data(fromTXTRecord: record)
    }

    private func publishBonjourAdvertisement(_ endpoint: KitchenLinkVenueHubEndpoint) {
        let name = "KitchenLink Hub \(deviceID.suffix(6).uppercased())"
        let type = KitchenLinkVenueHubBonjourContract.serviceType
        let txtRecord = makeBonjourTXTRecord(baseURL: endpoint.guestURL)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.bonjourService?.stop()
            let service = NetService(
                domain: "local.",
                type: type,
                name: name,
                port: Int32(endpoint.port)
            )
            service.setTXTRecord(txtRecord)
            service.publish()
            self.bonjourService = service
        }
    }

    private func updateBonjourAdvertisement(_ endpoint: KitchenLinkVenueHubEndpoint) {
        let txtRecord = makeBonjourTXTRecord(baseURL: endpoint.guestURL)
        DispatchQueue.main.async { [weak self] in
            self?.bonjourService?.setTXTRecord(txtRecord)
        }
    }

    private func stopBonjourAdvertisement() {
        DispatchQueue.main.async { [weak self] in
            self?.bonjourService?.stop()
            self?.bonjourService = nil
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
        case waitingForWiFi
        case failed(String)
    }

    @Published private(set) var state: State = .stopped
    @Published private(set) var endpoint: KitchenLinkVenueHubEndpoint?

    private let serverFactory: () throws -> any KitchenLinkVenueHubServing
    private var server: (any KitchenLinkVenueHubServing)?
    private var eventTask: Task<Void, Never>?

    init() {
        self.serverFactory = { try KitchenLinkVenueHubModel.makeDefaultServer() }
    }

    init(serverFactory: @escaping () throws -> any KitchenLinkVenueHubServing) {
        self.serverFactory = serverFactory
    }

    var isRunning: Bool {
        state == .running || state == .waitingForWiFi
    }

    var statusDetail: String {
        switch state {
        case .stopped:
            return "Der iPhone-Hub ist gestoppt."
        case .starting:
            return "Lokaler Hub und Gastseite werden gestartet …"
        case .running:
            return "Gastseite erreichbar. Lokale Bestellungen landen dauerhaft im Event-Log dieses iPhones."
        case .waitingForWiFi:
            return "Der Hub läuft, aber dieses iPhone hat gerade keine lokale WLAN-Adresse. Link und QR-Code aktualisieren sich automatisch."
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
            apply(endpoint)
            observeEvents(from: server)
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
        eventTask?.cancel()
        eventTask = nil
        server?.stop()
        server = nil
        endpoint = nil
        state = .stopped
    }

    private func apply(_ endpoint: KitchenLinkVenueHubEndpoint) {
        self.endpoint = endpoint
        state = endpoint.guestURL == nil ? .waitingForWiFi : .running
    }

    private func observeEvents(from server: any KitchenLinkVenueHubServing) {
        eventTask?.cancel()
        eventTask = Task { [weak self] in
            for await event in server.events {
                guard !Task.isCancelled, let self else { return }
                switch event {
                case .endpointChanged(let endpoint):
                    self.apply(endpoint)
                case .failed(let message):
                    self.server = nil
                    self.endpoint = nil
                    self.state = .failed(message)
                    return
                }
            }
        }
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

        return try KitchenLinkForegroundVenueHubServer(
            databaseURL: directory.appendingPathComponent("events.sqlite"),
            indexHTML: LocalGuestResources.indexHTML(),
            deviceID: KitchenLinkVenueHubIdentity.deviceID()
        )
    }
}
