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
        #expect(router.route(HTTPRequest(method: "POST", path: "/orders", body: body)).status == 415)
        let jsonHeaders = ["Content-Type": "application/json; charset=utf-8"]
        #expect(router.route(HTTPRequest(method: "POST", path: "/orders", headers: jsonHeaders, body: body)).status == 201)
        #expect(router.route(HTTPRequest(method: "POST", path: "/orders", headers: jsonHeaders, body: body)).status == 200)

        let changed = request(key: order.idempotencyKey, items: [OrderLineRequest(itemID: "lemonade", quantity: 1)])
        #expect(router.route(HTTPRequest(method: "POST", path: "/orders", headers: jsonHeaders, body: try encoder.encode(changed))).status == 409)
    }

    @Test func operatorProjectionMovesFromKitchenToWaiterAndServed() throws {
        let (service, _) = try fixture()
        let order = request(items: [OrderLineRequest(itemID: "fries", quantity: 2)])
        _ = try service.placeOrder(order)

        let kitchenOrder = try #require(service.operatorOrders().first)
        #expect(kitchenOrder.id == order.orderID)
        #expect(kitchenOrder.status == .preparing)
        #expect(kitchenOrder.totalMinor == 900)

        let readyRequest = LocalOrderStatusRequest(
            targetStatus: .ready,
            idempotencyKey: "status:\(order.orderID):ready"
        )
        let ready = try service.updateOperatorOrderStatus(orderID: order.orderID, request: readyRequest)
        let readyReplay = try service.updateOperatorOrderStatus(orderID: order.orderID, request: readyRequest)
        #expect(ready.orderStatus == .ready)
        #expect(!ready.replayed)
        #expect(readyReplay.replayed)
        #expect(readyReplay.eventID == ready.eventID)
        #expect(try service.operatorOrders().first?.status == .ready)

        let served = try service.updateOperatorOrderStatus(
            orderID: order.orderID,
            request: LocalOrderStatusRequest(
                targetStatus: .served,
                idempotencyKey: "status:\(order.orderID):served"
            )
        )
        #expect(served.orderStatus == .served)
        #expect(try service.operatorOrders().first?.status == .served)

        let delayedReadyReplay = try service.updateOperatorOrderStatus(
            orderID: order.orderID,
            request: readyRequest
        )
        #expect(delayedReadyReplay.replayed)
        #expect(delayedReadyReplay.eventID == ready.eventID)
        #expect(delayedReadyReplay.orderStatus == .ready)
        #expect(try service.persistedEvents().count == 3)
    }

    @Test func operatorStatusRejectsSkippedTransition() throws {
        let (service, _) = try fixture()
        let order = request()
        _ = try service.placeOrder(order)

        #expect(throws: LocalGuestOrderService.ServiceError.self) {
            try service.updateOperatorOrderStatus(
                orderID: order.orderID,
                request: LocalOrderStatusRequest(
                    targetStatus: .served,
                    idempotencyKey: "status:\(order.orderID):served"
                )
            )
        }
        #expect(try service.operatorOrders().first?.status == .preparing)
    }

    @Test func operatorHTTPRoutesExposeCommittedLifecycle() throws {
        let (service, _) = try fixture()
        let router = HTTPRouter(service: service, indexHTML: Data())
        let encoder = JSONEncoder()
        let jsonHeaders = ["Content-Type": "application/json"]
        let order = request()
        _ = try service.placeOrder(order)

        let feed = router.route(HTTPRequest(method: "GET", path: "/operator/orders"))
        #expect(feed.status == 200)
        let feedOrders = try JSONDecoder().decode([LocalOperatorOrder].self, from: feed.body)
        #expect(feedOrders.first?.status == .preparing)

        let statusBody = try encoder.encode(
            LocalOrderStatusRequest(
                targetStatus: .ready,
                idempotencyKey: "status:\(order.orderID):ready"
            )
        )
        let statusPath = "/operator/orders/\(order.orderID)/status"
        let updated = router.route(
            HTTPRequest(method: "POST", path: statusPath, headers: jsonHeaders, body: statusBody)
        )
        #expect(updated.status == 201)
        let updatedFeed = router.route(HTTPRequest(method: "GET", path: "/operator/orders"))
        let updatedOrders = try JSONDecoder().decode([LocalOperatorOrder].self, from: updatedFeed.body)
        #expect(updatedOrders.first?.status == .ready)
    }
}
