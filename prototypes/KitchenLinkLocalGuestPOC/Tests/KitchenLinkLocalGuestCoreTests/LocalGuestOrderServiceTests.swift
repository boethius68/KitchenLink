import Foundation
import KitchenLinkEventLog
import Testing
@testable import KitchenLinkLocalGuestCore

struct LocalGuestOrderServiceTests {
    private func fixture() throws -> (LocalGuestOrderService, String) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("kitchenlink-local-poc-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent("events.sqlite").path
        return (try LocalGuestOrderService(databasePath: path), path)
    }

    private func request(
        orderID: String = UUID().uuidString,
        key: String = UUID().uuidString,
        items: [OrderLineRequest] = [OrderLineRequest(itemID: "burger-classic", quantity: 1)],
        clientTotal: Int? = nil
    ) -> LocalOrderRequest {
        LocalOrderRequest(orderID: orderID, idempotencyKey: key, items: items, clientTotalMinor: clientTotal)
    }

    @Test func receiptIsReturnedAfterEventAndOutboxCommit() throws {
        let (service, path) = try fixture()
        let receipt = try service.placeOrder(request())

        #expect(receipt.status == "accepted")
        #expect(receipt.persistence == "local-event-log-committed")
        #expect(receipt.localSequence == 1)
        #expect(try service.persistedEvents().count == 1)

        let connection = try SQLiteConnection(path: path)
        try EventLogSchema.migrate(connection)
        let outboxCount = try connection.scalar("SELECT COUNT(*) FROM outbox;")
        #expect(outboxCount == "1")
    }

    @Test func retryReturnsOriginalReceiptWithoutSecondEvent() throws {
        let (service, _) = try fixture()
        let order = request()
        let first = try service.placeOrder(order)
        let replay = try service.placeOrder(order)

        #expect(replay.replayed)
        #expect(replay.eventID == first.eventID)
        #expect(replay.localSequence == first.localSequence)
        #expect(try service.persistedEvents().count == 1)
    }

    @Test func sameKeyWithDifferentPayloadConflicts() throws {
        let (service, _) = try fixture()
        let key = UUID().uuidString
        _ = try service.placeOrder(request(key: key))

        #expect(throws: LocalGuestOrderService.ServiceError.self) {
            try service.placeOrder(request(key: key, items: [OrderLineRequest(itemID: "fries", quantity: 1)]))
        }
        #expect(try service.persistedEvents().count == 1)
    }

    @Test func unknownItemIsRejectedWithoutPersistence() throws {
        let (service, _) = try fixture()

        #expect(throws: LocalGuestOrderService.ServiceError.self) {
            try service.placeOrder(request(items: [OrderLineRequest(itemID: "invented", quantity: 1)]))
        }
        #expect(try service.persistedEvents().isEmpty)
    }

    @Test func serverPriceWinsOverClientTotal() throws {
        let (service, _) = try fixture()
        let receipt = try service.placeOrder(request(items: [OrderLineRequest(itemID: "fries", quantity: 2)], clientTotal: 1))
        #expect(receipt.totalMinor == 900)
    }

    @Test func routerUsesSameOriginEndpointsAndConflictStatuses() throws {
        let (service, _) = try fixture()
        let router = HTTPRouter(service: service, indexHTML: Data("<h1>local</h1>".utf8))
        let encoder = JSONEncoder()
        let order = request()
        let body = try encoder.encode(order)

        #expect(router.route(HTTPRequest(method: "GET", path: "/")).status == 200)
        #expect(router.route(HTTPRequest(method: "GET", path: "/bootstrap")).status == 200)
        #expect(router.route(HTTPRequest(method: "POST", path: "/orders", body: body)).status == 201)
        #expect(router.route(HTTPRequest(method: "POST", path: "/orders", body: body)).status == 200)

        let changed = request(key: order.idempotencyKey, items: [OrderLineRequest(itemID: "lemonade", quantity: 1)])
        #expect(router.route(HTTPRequest(method: "POST", path: "/orders", body: try encoder.encode(changed))).status == 409)
    }
}
