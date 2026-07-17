import Foundation
import Testing
@testable import kitchenlink

struct OfflineTestError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

func isolatedDefaults(suiteName: String = UUID().uuidString) throws -> UserDefaults {
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        throw OfflineTestError("Could not create isolated UserDefaults suite: \(suiteName)")
    }
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

func connectToSuite(suiteName: String) throws -> UserDefaults {
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        throw OfflineTestError("Could not connect to UserDefaults suite: \(suiteName)")
    }
    return defaults
}

@MainActor
func eventually(_ condition: @MainActor () -> Bool, timeout: Duration = .seconds(8), interval: Duration = .milliseconds(200)) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if Task.isCancelled { return false }
        if condition() { return true }
        do {
            try await Task.sleep(for: interval)
        } catch {
            return false
        }
    }
    if Task.isCancelled { return false }
    return condition()
}

@MainActor
struct OfflineTestContext {
    let suiteName: String
    let ownerDefaults: UserDefaults
    let guestDefaults: UserDefaults
    let ownerRepo: LocalDemoRepository
    let guestRepo: LocalDemoRepository
    let ownerRelay: OrderRelayService
    let guestRelay: OrderRelayService
    init() throws {
        let suiteName = "KL_QA_002.\(UUID().uuidString)"
        let ownerDefaults = try isolatedDefaults(suiteName: suiteName)
        let guestDefaults = try isolatedDefaults(suiteName: suiteName)
        let ownerRepo = LocalDemoRepository(defaults: ownerDefaults)
        let guestRepo = LocalDemoRepository(defaults: guestDefaults)
        let ownerRelay = OrderRelayService(repository: ownerRepo)
        let guestRelay = OrderRelayService(repository: guestRepo)
        self.suiteName = suiteName
        self.ownerDefaults = ownerDefaults
        self.guestDefaults = guestDefaults
        self.ownerRepo = ownerRepo
        self.guestRepo = guestRepo
        self.ownerRelay = ownerRelay
        self.guestRelay = guestRelay
    }

    nonisolated func makeTestOrder(
        id: String = UUID().uuidString.lowercased(),
        status: OrderLifecycleStatus = .pending,
        tableLabel: String? = "A1",
        customerNote: String = "Ohne Eis"
    ) -> LiveOrderMessage {
        LiveOrderMessage(
            id: id,
            createdAt: .now,
            sourceDevice: "Test-Gerät",
            venueID: UUID().uuidString.lowercased(),
            venueName: "Test Venue",
            serviceMode: .dineIn,
            tableID: UUID().uuidString.lowercased(),
            tableLabel: tableLabel,
            customerNote: customerNote,
            items: [
                LiveOrderLine(
                    id: UUID().uuidString.lowercased(),
                    name: "Hauslimonade",
                    quantity: 2,
                    unitPriceCents: 450,
                    kind: .drink
                ),
                LiveOrderLine(
                    id: UUID().uuidString.lowercased(),
                    name: "Schnitzel",
                    quantity: 1,
                    unitPriceCents: 1290,
                    kind: .food
                )
            ],
            totalCents: 2190,
            status: status
        )
    }

    func cleanup() {
        ownerRelay.stopNetworking()
        guestRelay.stopNetworking()
        ownerRelay.clearReceivedOrders()
        guestRelay.clearReceivedOrders()
        ownerDefaults.removePersistentDomain(forName: suiteName)
        guestDefaults.removePersistentDomain(forName: suiteName)
    }
}
