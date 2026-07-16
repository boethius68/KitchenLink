import Foundation

/// Seeds a representative service moment through the existing sandbox order
/// domain (repository + relay). No second order model: every order is created
/// as `pending` and advanced through the regular lifecycle transitions.
@MainActor
enum KitchenLinkV2DemoOperationsSeeder {
    struct Scenario {
        let tableLabel: String?
        let serviceMode: ServiceMode
        let ageSeconds: TimeInterval
        let targetStatus: OrderLifecycleStatus
        let customerNote: String
        let itemOffsets: [Int]
    }

    static let scenarios: [Scenario] = [
        Scenario(
            tableLabel: "A1",
            serviceMode: .dineIn,
            ageSeconds: 12,
            targetStatus: .pending,
            customerNote: "",
            itemOffsets: [0, 1]
        ),
        Scenario(
            tableLabel: "B1",
            serviceMode: .dineIn,
            ageSeconds: 9 * 60,
            targetStatus: .preparing,
            customerNote: "",
            itemOffsets: [1, 2]
        ),
        Scenario(
            tableLabel: "A2",
            serviceMode: .dineIn,
            ageSeconds: 14 * 60,
            targetStatus: .served,
            customerNote: "",
            itemOffsets: [0, 2, 3]
        ),
        Scenario(
            tableLabel: "B2",
            serviceMode: .dineIn,
            ageSeconds: 4 * 60,
            targetStatus: .ready,
            customerNote: "",
            itemOffsets: [3]
        ),
        Scenario(
            tableLabel: nil,
            serviceMode: .pickup,
            ageSeconds: 90,
            targetStatus: .accepted,
            customerNote: "",
            itemOffsets: [2]
        ),
        Scenario(
            tableLabel: "B1",
            serviceMode: .dineIn,
            ageSeconds: 3 * 60,
            targetStatus: .preparing,
            customerNote: "Bitte ohne Ei",
            itemOffsets: [0]
        )
    ]

    /// Replaces the local sandbox orders with the demo scenario and returns
    /// how many orders were created.
    @discardableResult
    static func seed(
        store: KitchenLinkStore,
        relay: OrderRelayService,
        now: Date = Date()
    ) async -> Int {
        relay.startHostingAsOwner()
        relay.clearReceivedOrders()

        let menuItems = flattenedMenuItems(from: store.menuSections)
        var createdCount = 0

        for scenario in scenarios {
            let lines = orderLines(for: scenario, menuItems: menuItems)
            guard !lines.isEmpty else { continue }

            let table = scenario.tableLabel.flatMap { label in
                store.venueProfile.tables.first {
                    $0.label.caseInsensitiveCompare(label) == .orderedSame
                }
            }
            let order = LiveOrderMessage(
                id: UUID().uuidString.lowercased(),
                createdAt: now.addingTimeInterval(-scenario.ageSeconds),
                sourceDevice: "Demo-Szenario",
                venueID: store.venueProfile.id,
                venueName: store.venueProfile.name,
                serviceMode: scenario.serviceMode,
                tableID: table?.id,
                tableLabel: table?.label ?? scenario.tableLabel,
                customerNote: scenario.customerNote,
                items: lines,
                totalCents: lines.reduce(0) { $0 + $1.lineTotalCents },
                status: .pending
            )

            guard var placedOrder = await relay.send(order: order) else { continue }
            createdCount += 1

            while placedOrder.status != scenario.targetStatus,
                  let nextStatus = placedOrder.status.primaryNextStatus {
                let didAdvance = await relay.updateStatus(for: placedOrder, to: nextStatus)
                guard didAdvance else { break }
                placedOrder = placedOrder.with(id: placedOrder.id, status: nextStatus)
            }
        }

        return createdCount
    }

    private static func flattenedMenuItems(
        from sections: [MenuSectionData]
    ) -> [MenuItemData] {
        let items = sections.flatMap(\.items).filter { $0.priceCents > 0 }
        guard items.isEmpty else { return items }
        return [
            MenuItemData(
                id: "demo-fallback-schnitzel",
                name: "Wiener Schnitzel",
                description: "Demo",
                priceCents: 2_280,
                kind: .food
            ),
            MenuItemData(
                id: "demo-fallback-spaetzle",
                name: "Käsespätzle",
                description: "Demo",
                priceCents: 1_450,
                kind: .food
            )
        ]
    }

    private static func orderLines(
        for scenario: Scenario,
        menuItems: [MenuItemData]
    ) -> [LiveOrderLine] {
        guard !menuItems.isEmpty else { return [] }
        return scenario.itemOffsets.enumerated().map { lineIndex, offset in
            let item = menuItems[offset % menuItems.count]
            return LiveOrderLine(
                id: "\(item.id)-demo-\(lineIndex)",
                name: item.name,
                quantity: 1 + (offset + lineIndex) % 2,
                unitPriceCents: item.priceCents,
                kind: item.kind
            )
        }
    }
}
