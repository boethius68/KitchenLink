import Foundation
import Testing
@testable import kitchenlink

private struct LoopbackAddressProvider: KitchenLinkLocalAddressProviding {
    func wifiIPv4Address() -> String? { "127.0.0.1" }
}

private final class VenueHubServerStub: KitchenLinkVenueHubServing {
    let endpoint: KitchenLinkVenueHubEndpoint
    private(set) var didStop = false

    init(endpoint: KitchenLinkVenueHubEndpoint) {
        self.endpoint = endpoint
    }

    func start() async throws -> KitchenLinkVenueHubEndpoint { endpoint }
    func stop() { didStop = true }
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
            guestURL: try #require(URL(string: "http://192.168.1.44:8123")),
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
}
