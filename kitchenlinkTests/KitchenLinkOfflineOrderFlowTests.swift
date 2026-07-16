import Foundation
import Testing
@testable import kitchenlink

private let transitionCases: [(from: OrderLifecycleStatus, to: OrderLifecycleStatus, shouldSucceed: Bool)] = [
    (.pending, .accepted, true),
    (.accepted, .preparing, true),
    (.preparing, .ready, true),
    (.ready, .served, true),
    (.pending, .canceled, true),
    (.accepted, .canceled, true),
    (.preparing, .canceled, true),
    (.ready, .canceled, true),
    (.pending, .preparing, false),
    (.pending, .ready, false),
    (.pending, .served, false),
    (.pending, .pending, false),
    (.accepted, .ready, false),
    (.accepted, .served, false),
    (.accepted, .accepted, false),
    (.preparing, .served, false),
    (.preparing, .accepted, false),
    (.preparing, .preparing, false),
    (.ready, .preparing, false),
    (.ready, .accepted, false),
    (.ready, .pending, false),
    (.ready, .ready, false),
    (.served, .pending, false),
    (.served, .accepted, false),
    (.served, .preparing, false),
    (.served, .ready, false),
    (.served, .served, false),
    (.served, .canceled, false),
    (.canceled, .pending, false),
    (.canceled, .accepted, false),
    (.canceled, .preparing, false),
    (.canceled, .ready, false),
    (.canceled, .served, false),
    (.canceled, .canceled, false),
]

@Test @MainActor
func guestSendsOrder_ownerSeesPending() async throws {
    let context = try OfflineTestContext()
    defer { context.cleanup() }
    let order = context.makeTestOrder()
    context.guestRelay.startBrowsingAsCustomer()
    context.ownerRelay.startHostingAsOwner()

    let placedOrder = await context.guestRelay.send(order: order)
    guard let orderID = placedOrder?.id else {
        Issue.record("Guest order placement returned nil")
        return
    }

    let ownerSeesOrder = await eventually { context.ownerRelay.receivedOrders.contains(where: { $0.id == orderID }) }
    #expect(ownerSeesOrder, "Owner relay should eventually receive the pending order via polling")
    #expect(placedOrder?.status == .pending)

    let storedOrder = try context.ownerRepo.loadOrder(orderID: orderID)
    #expect(storedOrder?.status == .pending)
    #expect(storedOrder?.totalCents == 2190)
    #expect(storedOrder?.tableLabel == "A1")
    #expect(storedOrder?.customerNote == "Ohne Eis")
    #expect(storedOrder?.items.count == 2)
}

@Test @MainActor
func fullLifecycleChainViaOwner() async throws {
    let context = try OfflineTestContext()
    defer { context.cleanup() }
    let order = context.makeTestOrder()
    context.guestRelay.startBrowsingAsCustomer()
    context.ownerRelay.startHostingAsOwner()

    let placedOrder = await context.guestRelay.send(order: order)
    guard let orderID = placedOrder?.id else {
        Issue.record("Guest order placement returned nil")
        return
    }

    let ownerReady = await eventually { context.ownerRelay.receivedOrders.contains(where: { $0.id == orderID }) }
    #expect(ownerReady, "Owner must see the pending order")

    for expectedStatus in [OrderLifecycleStatus.accepted, .preparing, .ready, .served] {
        guard let currentOrder = try context.ownerRepo.loadOrder(orderID: orderID) else {
            Issue.record("Order \(orderID) not found before transition to \(expectedStatus)")
            return
        }
        let success = await context.ownerRelay.updateStatus(for: currentOrder, to: expectedStatus)
        #expect(success, "Transition to \(expectedStatus) must succeed")
        guard let stored = try context.ownerRepo.loadOrder(orderID: orderID) else {
            Issue.record("Order \(orderID) not found after transition to \(expectedStatus)")
            return
        }
        #expect(stored.status == expectedStatus, "Status must be \(expectedStatus) after update")
        let ownerSynced = context.ownerRelay.receivedOrders.first(where: { $0.id == orderID })
        #expect(ownerSynced?.status == expectedStatus, "Owner relay must reflect status \(expectedStatus)")
    }
}

@Test @MainActor
func guestTracksFullChain() async throws {
    let context = try OfflineTestContext()
    defer { context.cleanup() }
    let order = context.makeTestOrder()
    context.guestRelay.startBrowsingAsCustomer()
    context.ownerRelay.startHostingAsOwner()

    let placedOrder = await context.guestRelay.send(order: order)
    guard let orderID = placedOrder?.id else {
        Issue.record("Guest order placement returned nil")
        return
    }

    let ownerReady = await eventually { context.ownerRelay.receivedOrders.contains(where: { $0.id == orderID }) }
    #expect(ownerReady, "Owner must see the pending order before advancing")

    context.guestRelay.startTrackingCustomerOrder(orderID: orderID)

    for expectedStatus in [OrderLifecycleStatus.accepted, .preparing, .ready, .served] {
        guard let currentOrder = try context.ownerRepo.loadOrder(orderID: orderID) else {
            Issue.record("Order \(orderID) not found")
            return
        }
        let success = await context.ownerRelay.updateStatus(for: currentOrder, to: expectedStatus)
        #expect(success, "Owner transition to \(expectedStatus) must succeed")

        let guestObserved = await eventually { context.guestRelay.trackedCustomerOrder?.status == expectedStatus }
        #expect(guestObserved, "Guest tracker must observe status \(expectedStatus)")
    }
}

@Test @MainActor
func invalidTransitionsDontChangeState() async throws {
    let context = try OfflineTestContext()
    defer { context.cleanup() }
    let order = context.makeTestOrder()
    context.ownerRelay.startHostingAsOwner()

    let placedOrder = try context.ownerRepo.createOrder(order)
    let orderID = placedOrder.id

    let invalidCases: [(from: OrderLifecycleStatus, to: OrderLifecycleStatus)] = [
        (.pending, .preparing), (.pending, .ready), (.pending, .served),
        (.accepted, .ready), (.accepted, .served),
        (.preparing, .served),
        (.served, .canceled), (.served, .accepted),
        (.canceled, .pending),
        (.ready, .accepted),
    ]

    for (currentStatus, invalidTarget) in invalidCases {
        guard let updatedOrder = try context.ownerRepo.updateOrderStatus(orderID: orderID, to: currentStatus) else {
            Issue.record("Could not set order to \(currentStatus.rawValue)")
            return
        }
        let result = await context.ownerRelay.updateStatus(for: updatedOrder, to: invalidTarget)
        #expect(!result, "Transition \(currentStatus.rawValue) -> \(invalidTarget.rawValue) must be rejected")
        guard let stored = try context.ownerRepo.loadOrder(orderID: orderID) else {
            Issue.record("Order not found after rejected transition")
            return
        }
        #expect(stored.status == currentStatus, "Status must remain \(currentStatus.rawValue) after rejected transition to \(invalidTarget.rawValue)")
    }
}

@Test @MainActor
func tableDrivenTransitionCoverage() async throws {
    let context = try OfflineTestContext()
    defer { context.cleanup() }
    let baseOrder = context.makeTestOrder()
    context.ownerRelay.startHostingAsOwner()

    for (fromStatus, toStatus, shouldSucceed) in transitionCases {
        let order = baseOrder.with(id: UUID().uuidString.lowercased(), status: fromStatus)
        let created = try context.ownerRepo.createOrder(order)
        let storedOrder = if fromStatus != .pending {
            try context.ownerRepo.updateOrderStatus(orderID: created.id, to: fromStatus) ?? created
        } else { created }
        #expect(storedOrder.status == fromStatus, "Setup: order must be at \(fromStatus.rawValue)")

        let result = await context.ownerRelay.updateStatus(for: storedOrder, to: toStatus)
        #expect(result == shouldSucceed, "Transition \(fromStatus.rawValue) -> \(toStatus.rawValue): expected success=\(shouldSucceed), got \(result)")

        let finalStatus = try context.ownerRepo.loadOrder(orderID: storedOrder.id)?.status
        if shouldSucceed {
            #expect(finalStatus == toStatus, "After allowed transition \(fromStatus.rawValue) -> \(toStatus.rawValue), status must be \(toStatus.rawValue)")
        } else {
            #expect(finalStatus == fromStatus, "After rejected transition \(fromStatus.rawValue) -> \(toStatus.rawValue), status must remain \(fromStatus.rawValue)")
        }
    }
}

@Test @MainActor
func persistenceAcrossRelayRecreation() async throws {
    let context = try OfflineTestContext()
    defer { context.cleanup() }
    let order = context.makeTestOrder(tableLabel: "B2", customerNote: "Bitte extra scharf")
    context.ownerRelay.startHostingAsOwner()

    let placedOrder = await context.ownerRelay.send(order: order)
    guard let orderID = placedOrder?.id else {
        Issue.record("Owner order placement returned nil")
        return
    }
    #expect(try context.ownerRepo.loadOrder(orderID: orderID)?.status == .pending)

    guard let accepted = try context.ownerRepo.updateOrderStatus(orderID: orderID, to: .preparing) else {
        Issue.record("Could not update status to preparing")
        return
    }

    let newOwnerDefaults = try connectToSuite(suiteName: context.suiteName)
    let newOwnerRepo = LocalDemoRepository(defaults: newOwnerDefaults)
    let newOwnerRelay = OrderRelayService(repository: newOwnerRepo)

    guard let reloadedOrder = try newOwnerRepo.loadOrder(orderID: orderID) else {
        Issue.record("Order not found after relay recreation")
        return
    }
    #expect(reloadedOrder.status == .preparing)
    #expect(reloadedOrder.items.count == 2)
    #expect(reloadedOrder.items.first?.name == "Hauslimonade")
    #expect(reloadedOrder.totalCents == 2190)
    #expect(reloadedOrder.tableLabel == "B2")
    #expect(reloadedOrder.customerNote == "Bitte extra scharf")

    newOwnerRelay.stopNetworking()
}

@Test @MainActor
func relayTeardownLeavesNoTraces() async throws {
    let context = try OfflineTestContext()
    let order = context.makeTestOrder()
    context.guestRelay.startBrowsingAsCustomer()
    context.ownerRelay.startHostingAsOwner()

    let placedOrder = await context.guestRelay.send(order: order)
    guard let orderID = placedOrder?.id else {
        Issue.record("Guest order placement returned nil")
        return
    }

    context.guestRelay.startTrackingCustomerOrder(orderID: orderID)
    let ownerReady = await eventually { context.ownerRelay.receivedOrders.contains(where: { $0.id == orderID }) }
    #expect(ownerReady)

    context.ownerRelay.stopNetworking()
    context.guestRelay.stopNetworking()
    context.ownerRelay.clearReceivedOrders()
    context.guestRelay.clearReceivedOrders()

    context.ownerDefaults.removePersistentDomain(forName: context.suiteName)
    context.guestDefaults.removePersistentDomain(forName: context.suiteName)

    let loadedOrders = try context.ownerRepo.loadOrders()
    #expect(loadedOrders.isEmpty, "Order storage must be empty after cleanup")
    #expect(context.ownerRelay.receivedOrders.isEmpty, "Owner receivedOrders must be empty after cleanup")
    #expect(context.guestRelay.trackedCustomerOrder == nil, "Guest trackedCustomerOrder must be nil after cleanup")
}
