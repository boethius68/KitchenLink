import Foundation
import Testing
@testable import kitchenlink

actor KitchenLinkLocalOperatorTransportSpy: KitchenLinkLocalOperatorTransport {
    private var wireOrders: [KitchenLinkLocalOperatorWireOrder]
    private(set) var updates: [(String, OrderLifecycleStatus)] = []

    init(orders: [KitchenLinkLocalOperatorWireOrder]) {
        self.wireOrders = orders
    }

    func loadOrders(baseURL: URL) async throws -> [KitchenLinkLocalOperatorWireOrder] {
        wireOrders
    }

    func updateStatus(
        baseURL: URL,
        orderID: String,
        targetStatus: OrderLifecycleStatus
    ) async throws -> KitchenLinkLocalOperatorStatusReceipt {
        updates.append((orderID, targetStatus))
        if let index = wireOrders.firstIndex(where: { $0.id == orderID }) {
            let order = wireOrders[index]
            wireOrders[index] = KitchenLinkLocalOperatorWireOrder(
                id: order.id,
                localSequence: order.localSequence,
                createdAtMs: order.createdAtMs,
                venueID: order.venueID,
                currency: order.currency,
                totalMinor: order.totalMinor,
                lines: order.lines,
                status: targetStatus.rawValue
            )
        }
        return KitchenLinkLocalOperatorStatusReceipt(
            status: "accepted",
            orderID: orderID,
            orderStatus: targetStatus.rawValue,
            eventID: UUID().uuidString,
            localSequence: 2,
            replayed: false,
            persistence: "local-event-log-committed"
        )
    }

    func recordedUpdates() -> [(String, OrderLifecycleStatus)] {
        updates
    }
}

struct KitchenLinkLocalOperationsTests {
    private func wireOrder(status: String = "preparing") -> KitchenLinkLocalOperatorWireOrder {
        KitchenLinkLocalOperatorWireOrder(
            id: "8D847214-A339-4C85-9B47-B5076734C4A6",
            localSequence: 7,
            createdAtMs: 1_750_000_000_000,
            venueID: "venue-local-poc",
            currency: "EUR",
            totalMinor: 1_640,
            lines: [
                KitchenLinkLocalOperatorWireLine(
                    itemID: "burger-veggie",
                    name: "Veggie Burger",
                    quantity: 1,
                    unitPriceMinor: 1_190,
                    lineTotalMinor: 1_190
                ),
                KitchenLinkLocalOperatorWireLine(
                    itemID: "fries",
                    name: "Pommes",
                    quantity: 1,
                    unitPriceMinor: 450,
                    lineTotalMinor: 450
                )
            ],
            status: status
        )
    }

    @Test @MainActor
    func refreshMapsHubOrderIntoExistingOrderDomain() async throws {
        let spy = KitchenLinkLocalOperatorTransportSpy(orders: [wireOrder()])
        let suite = "KitchenLinkLocalOperationsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = KitchenLinkLocalOperationsModel(transport: spy, defaults: defaults)

        await model.refresh()

        let order = try #require(model.orders.first)
        #expect(model.isConnected)
        #expect(order.status == .preparing)
        #expect(order.items.map(\.name) == ["Veggie Burger", "Pommes"])
        #expect(order.totalCents == 1_640)
        #expect(order.sourceDevice == "Lokales Gast-WLAN · #7")
    }

    @Test @MainActor
    func kitchenReadyTransitionRefreshesOrderForWaiterMode() async throws {
        let spy = KitchenLinkLocalOperatorTransportSpy(orders: [wireOrder()])
        let suite = "KitchenLinkLocalOperationsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = KitchenLinkLocalOperationsModel(transport: spy, defaults: defaults)
        await model.refresh()
        let order = try #require(model.orders.first)

        let didUpdate = await model.update(order: order, to: .ready)

        #expect(didUpdate)
        #expect(model.orders.first?.status == .ready)
        let updates = await spy.recordedUpdates()
        #expect(updates.count == 1)
        #expect(updates.first?.0 == order.id)
        #expect(updates.first?.1 == .ready)
    }

    @Test @MainActor
    func hubAddressAcceptsIPAddressWithoutScheme() throws {
        let suite = "KitchenLinkLocalOperationsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = KitchenLinkLocalOperationsModel(
            transport: KitchenLinkLocalOperatorTransportSpy(orders: []),
            defaults: defaults
        )
        model.hubAddress = "192.168.178.110:8080"

        #expect(model.normalizedHubURL()?.absoluteString == "http://192.168.178.110:8080")
    }

    @Test @MainActor
    func internalIPhoneHubDoesNotOverwriteSavedMacFallback() throws {
        let suite = "KitchenLinkLocalOperationsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let macHub = "http://192.168.1.20:8080"
        defaults.set(macHub, forKey: KitchenLinkLocalOperationsModel.addressDefaultsKey)
        let model = KitchenLinkLocalOperationsModel(
            transport: KitchenLinkLocalOperatorTransportSpy(orders: []),
            defaults: defaults
        )

        model.connect(to: try #require(URL(string: "http://127.0.0.1:8123")))
        defer { model.disconnect() }

        #expect(model.hubAddress == macHub)
        #expect(defaults.string(forKey: KitchenLinkLocalOperationsModel.addressDefaultsKey) == macHub)
    }
}
