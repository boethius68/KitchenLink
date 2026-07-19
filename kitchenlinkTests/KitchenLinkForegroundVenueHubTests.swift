import Foundation
import Testing
@testable import kitchenlink

private struct LoopbackAddressProvider: KitchenLinkLocalAddressProviding {
    func wifiIPv4Address() -> String? { "127.0.0.1" }
}

private final class VenueHubServerStub: KitchenLinkVenueHubServing, @unchecked Sendable {
    let endpoint: KitchenLinkVenueHubEndpoint
    let events: AsyncStream<KitchenLinkVenueHubServerEvent>
    private let eventContinuation: AsyncStream<KitchenLinkVenueHubServerEvent>.Continuation
    private(set) var didStop = false

    init(endpoint: KitchenLinkVenueHubEndpoint) {
        let eventStream = AsyncStream.makeStream(
            of: KitchenLinkVenueHubServerEvent.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        self.endpoint = endpoint
        self.events = eventStream.stream
        self.eventContinuation = eventStream.continuation
    }

    func start() async throws -> KitchenLinkVenueHubEndpoint { endpoint }
    func stop() {
        didStop = true
        eventContinuation.finish()
    }

    func send(_ event: KitchenLinkVenueHubServerEvent) {
        eventContinuation.yield(event)
    }
}

private final class VenueHubFactoryThreadObservation: @unchecked Sendable {
    private let lock = NSLock()
    private var storedIsMainThread: Bool?

    func recordCurrentThread() {
        lock.lock()
        storedIsMainThread = Thread.isMainThread
        lock.unlock()
    }

    var isMainThread: Bool? {
        lock.lock()
        defer { lock.unlock() }
        return storedIsMainThread
    }
}

private final class MutableAddressProvider: KitchenLinkLocalAddressProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var storedAddress: String?

    init(_ address: String?) {
        storedAddress = address
    }

    func wifiIPv4Address() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return storedAddress
    }

    func setAddress(_ address: String?) {
        lock.lock()
        storedAddress = address
        lock.unlock()
    }
}

struct KitchenLinkForegroundVenueHubTests {
    @Test
    func parserWaitsForCompleteBodyAndPreservesRequest() throws {
        let body = Data(#"{"items":[{"itemID":"fries","quantity":1}]}"#.utf8)
        let head = Data("POST /orders HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\n\r\n".utf8)

        #expect(try KitchenLinkHTTPRequestParser.parseIfComplete(head) == nil)

        var complete = head
        complete.append(body)
        let parsed = try KitchenLinkHTTPRequestParser.parseIfComplete(complete)
        let request = try #require(parsed)
        #expect(request.method == "POST")
        #expect(request.path == "/orders")
        #expect(request.headers["content-type"] == "application/json")
        #expect(request.body == body)
    }

    @Test
    func parserRejectsOversizedRequest() {
        let bytes = Data(repeating: 65, count: KitchenLinkHTTPRequestParser.maximumRequestBytes + 1)
        #expect(throws: KitchenLinkVenueHubError.self) {
            try KitchenLinkHTTPRequestParser.parseIfComplete(bytes)
        }
    }

    @Test @MainActor
    func modelPublishesEndpointAndStopsServer() async throws {
        let endpoint = KitchenLinkVenueHubEndpoint(
            guestURL: URL(string: "http://192.168.1.44:8123"),
            operatorURL: try #require(URL(string: "http://127.0.0.1:8123")),
            port: 8_123
        )
        let server = VenueHubServerStub(endpoint: endpoint)
        let model = KitchenLinkVenueHubModel(serverFactory: { server })

        #expect(await model.start() == endpoint)
        #expect(model.state == .running)
        #expect(model.endpoint == endpoint)

        model.stop()
        #expect(server.didStop)
        #expect(model.state == .stopped)
        #expect(model.endpoint == nil)
    }

    @Test @MainActor
    func modelCreatesServerAwayFromMainThread() async throws {
        let endpoint = KitchenLinkVenueHubEndpoint(
            guestURL: URL(string: "http://192.168.1.44:8123"),
            operatorURL: try #require(URL(string: "http://127.0.0.1:8123")),
            port: 8_123
        )
        let server = VenueHubServerStub(endpoint: endpoint)
        let observation = VenueHubFactoryThreadObservation()
        let model = KitchenLinkVenueHubModel(serverFactory: {
            observation.recordCurrentThread()
            return server
        })

        #expect(await model.start() == endpoint)
        #expect(observation.isMainThread == false)

        model.stop()
    }

    @Test @MainActor
    func modelKeepsHubRunningWhileWiFiIsUnavailableAndAppliesNewAddress() async throws {
        let waitingEndpoint = KitchenLinkVenueHubEndpoint(
            guestURL: nil,
            operatorURL: try #require(URL(string: "http://127.0.0.1:8123")),
            port: 8_123
        )
        let availableEndpoint = KitchenLinkVenueHubEndpoint(
            guestURL: URL(string: "http://192.168.1.45:8123"),
            operatorURL: waitingEndpoint.operatorURL,
            port: waitingEndpoint.port
        )
        let server = VenueHubServerStub(endpoint: waitingEndpoint)
        let model = KitchenLinkVenueHubModel(serverFactory: { server })

        #expect(await model.start() == waitingEndpoint)
        #expect(model.state == .waitingForWiFi)
        #expect(model.isRunning)

        server.send(.endpointChanged(availableEndpoint))
        await waitUntil { model.endpoint == availableEndpoint }

        #expect(model.state == .running)
        #expect(model.endpoint == availableEndpoint)
    }

    @Test @MainActor
    func foregroundServerPublishesWiFiLossAndRecoveryWithoutChangingPort() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KitchenLinkForegroundVenueHubRecoveryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let addressProvider = MutableAddressProvider(nil)
        let server = try KitchenLinkForegroundVenueHubServer(
            databaseURL: directory.appendingPathComponent("events.sqlite"),
            indexHTML: Data("<html>KitchenLink</html>".utf8),
            deviceID: "ios-recovery-test-hub",
            addressProvider: addressProvider,
            addressPollInterval: 0.02
        )
        let model = KitchenLinkVenueHubModel(serverFactory: { server })
        let initialEndpoint = try #require(await model.start())
        defer { model.stop() }

        #expect(initialEndpoint.guestURL == nil)
        #expect(model.state == .waitingForWiFi)

        addressProvider.setAddress("192.168.1.45")
        await waitUntil { model.endpoint?.guestURL?.host == "192.168.1.45" }
        #expect(model.endpoint?.port == initialEndpoint.port)
        #expect(model.endpoint?.operatorURL == initialEndpoint.operatorURL)
        #expect(model.state == .running)

        addressProvider.setAddress(nil)
        await waitUntil { model.state == .waitingForWiFi }
        #expect(model.endpoint?.guestURL == nil)
        #expect(model.endpoint?.port == initialEndpoint.port)
    }

    @Test
    func foregroundServerAcceptsAndProjectsOrderOverLoopback() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KitchenLinkForegroundVenueHubTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let server = try KitchenLinkForegroundVenueHubServer(
            databaseURL: directory.appendingPathComponent("events.sqlite"),
            indexHTML: Data("<html>KitchenLink</html>".utf8),
            deviceID: "ios-test-hub",
            addressProvider: LoopbackAddressProvider()
        )
        let endpoint = try await server.start()
        defer { server.stop() }

        let healthURL = endpoint.operatorURL.appendingPathComponent("health")
        let (_, healthResponse) = try await URLSession.shared.data(from: healthURL)
        #expect((healthResponse as? HTTPURLResponse)?.statusCode == 200)

        let orderID = UUID().uuidString.lowercased()
        let orderBody = Data(
            """
            {"orderID":"\(orderID)","idempotencyKey":"ios-e2e-\(orderID)","items":[{"itemID":"burger-veggie","quantity":1},{"itemID":"fries","quantity":1}],"clientTotalMinor":1640}
            """.utf8
        )
        var placeRequest = URLRequest(url: endpoint.operatorURL.appendingPathComponent("orders"))
        placeRequest.httpMethod = "POST"
        placeRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        placeRequest.httpBody = orderBody
        let (receiptData, receiptResponse) = try await URLSession.shared.data(for: placeRequest)
        #expect((receiptResponse as? HTTPURLResponse)?.statusCode == 201)
        let receiptText = try #require(String(data: receiptData, encoding: .utf8))
        #expect(receiptText.contains("local-event-log-committed"))

        let ordersURL = endpoint.operatorURL.appendingPathComponent("operator/orders")
        let (ordersData, ordersResponse) = try await URLSession.shared.data(from: ordersURL)
        #expect((ordersResponse as? HTTPURLResponse)?.statusCode == 200)
        let ordersText = try #require(String(data: ordersData, encoding: .utf8))
        #expect(ordersText.contains(orderID))
        #expect(ordersText.contains("preparing"))
    }

    @MainActor
    private func waitUntil(
        timeout: Duration = .seconds(2),
        condition: @escaping @MainActor () -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition(), clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}
