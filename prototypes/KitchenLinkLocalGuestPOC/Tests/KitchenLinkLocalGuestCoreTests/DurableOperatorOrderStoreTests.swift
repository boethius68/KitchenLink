import Foundation
import KitchenLinkEventLog
import Testing
@testable import KitchenLinkLocalGuestCore

struct DurableOperatorOrderStoreTests {
    private let venue = "kitchenlink-local-orders"

    private func makePath() throws -> String {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kitchenlink-durable-orders-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("orders.sqlite").path
    }

    private func store(at path: String) throws -> DurableOperatorOrderStore {
        try DurableOperatorOrderStore(databasePath: path, deviceID: "test-device")
    }

    private func snapshot(_ text: String) -> Data { Data(text.utf8) }

    @Test func placeProjectsSingleOrder() throws {
        let store = try store(at: try makePath())
        let placed = try store.placeOrder(
            orderID: "order-1",
            venueID: venue,
            snapshot: snapshot("burger"),
            initialStatus: "pending"
        )
        #expect(placed.status == "pending")

        let orders = try store.orders(venueID: venue)
        #expect(orders.count == 1)
        #expect(orders.first?.orderID == "order-1")
        #expect(orders.first?.snapshot == snapshot("burger"))
        #expect(orders.first?.status == "pending")
    }

    @Test func placeIsIdempotentOnIdenticalRetry() throws {
        let store = try store(at: try makePath())
        _ = try store.placeOrder(orderID: "order-1", venueID: venue, snapshot: snapshot("burger"), initialStatus: "pending")
        _ = try store.placeOrder(orderID: "order-1", venueID: venue, snapshot: snapshot("burger"), initialStatus: "pending")

        #expect(try store.orders(venueID: venue).count == 1)
    }

    @Test func placeSameIDDifferentSnapshotConflicts() throws {
        let store = try store(at: try makePath())
        _ = try store.placeOrder(orderID: "order-1", venueID: venue, snapshot: snapshot("burger"), initialStatus: "pending")

        #expect(throws: DurableOperatorOrderStore.StoreError.self) {
            _ = try store.placeOrder(orderID: "order-1", venueID: venue, snapshot: snapshot("changed"), initialStatus: "pending")
        }
    }

    @Test func statusUpdatesProjectLatest() throws {
        let store = try store(at: try makePath())
        _ = try store.placeOrder(orderID: "order-1", venueID: venue, snapshot: snapshot("burger"), initialStatus: "pending")

        _ = try store.updateStatus(orderID: "order-1", venueID: venue, to: "accepted")
        let afterAccept = try store.order(orderID: "order-1", venueID: venue)
        #expect(afterAccept?.status == "accepted")

        _ = try store.updateStatus(orderID: "order-1", venueID: venue, to: "preparing")
        let afterPreparing = try store.order(orderID: "order-1", venueID: venue)
        #expect(afterPreparing?.status == "preparing")
    }

    @Test func statusUpdateIsIdempotent() throws {
        let store = try store(at: try makePath())
        _ = try store.placeOrder(orderID: "order-1", venueID: venue, snapshot: snapshot("burger"), initialStatus: "pending")

        let first = try store.updateStatus(orderID: "order-1", venueID: venue, to: "accepted")
        let second = try store.updateStatus(orderID: "order-1", venueID: venue, to: "accepted")
        #expect(first?.status == "accepted")
        #expect(second?.status == "accepted")
        // The replayed transition must not add a second event to the aggregate.
        #expect(first?.localSequence == second?.localSequence)
    }

    @Test func statusUpdateForUnknownOrderReturnsNil() throws {
        let store = try store(at: try makePath())
        #expect(try store.updateStatus(orderID: "missing", venueID: venue, to: "accepted") == nil)
    }

    @Test func ordersSurviveReopen() throws {
        let path = try makePath()
        var first: DurableOperatorOrderStore? = try store(at: path)
        _ = try first?.placeOrder(orderID: "order-1", venueID: venue, snapshot: snapshot("burger"), initialStatus: "pending")
        _ = try first?.updateStatus(orderID: "order-1", venueID: venue, to: "accepted")
        first = nil // closes the SQLite connection on deinit

        let reopened = try store(at: path)
        let orders = try reopened.orders(venueID: venue)
        #expect(orders.count == 1)
        #expect(orders.first?.status == "accepted")
        #expect(orders.first?.snapshot == snapshot("burger"))
    }

    @Test func clearHidesPriorOrdersButKeepsLater() throws {
        let store = try store(at: try makePath())
        _ = try store.placeOrder(orderID: "order-1", venueID: venue, snapshot: snapshot("a"), initialStatus: "pending")
        _ = try store.placeOrder(orderID: "order-2", venueID: venue, snapshot: snapshot("b"), initialStatus: "pending")

        try store.clear(venueID: venue)
        #expect(try store.orders(venueID: venue).isEmpty)

        _ = try store.placeOrder(orderID: "order-3", venueID: venue, snapshot: snapshot("c"), initialStatus: "pending")
        let orders = try store.orders(venueID: venue)
        #expect(orders.count == 1)
        #expect(orders.first?.orderID == "order-3")
    }

    @Test func ordersAreOldestFirst() throws {
        let clock = FakeClock(startMs: 1_000)
        let store = try DurableOperatorOrderStore(databasePath: try makePath(), deviceID: "test-device", clock: clock)
        _ = try store.placeOrder(orderID: "order-1", venueID: venue, snapshot: snapshot("a"), initialStatus: "pending")
        clock.advance(by: 1_000)
        _ = try store.placeOrder(orderID: "order-2", venueID: venue, snapshot: snapshot("b"), initialStatus: "pending")

        let ids = try store.orders(venueID: venue).map(\.orderID)
        #expect(ids == ["order-1", "order-2"])
    }
}
