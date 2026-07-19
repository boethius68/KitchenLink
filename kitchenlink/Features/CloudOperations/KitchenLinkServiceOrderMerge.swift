import Foundation

/// Zusammenführung von Online- und lokalen Bestellungen für die eine
/// Service-Liste (KL-CLOUD-001). Lokale Hub-Bestellungen starten als
/// `preparing`; Online-Bestellungen aus dem Gast-Web starten als `pending`
/// (Blueprint §6.3: automatische Annahme ist der Standard, deshalb landen sie
/// direkt in der Küche statt in einem eigenen Annahme-Schritt).
enum KitchenLinkServiceOrderMerge {
    static let kitchenOnlineStatuses: Set<OrderLifecycleStatus> = [
        .pending, .accepted, .preparing
    ]

    /// Küche: alles, was noch zubereitet werden muss, älteste zuerst.
    static func kitchenOrders(
        local: [LiveOrderMessage],
        online: [LiveOrderMessage]
    ) -> [LiveOrderMessage] {
        let merged = local.filter { $0.status == .preparing }
            + online.filter { kitchenOnlineStatuses.contains($0.status) }
        return merged.sorted { $0.createdAt < $1.createdAt }
    }

    /// Kellner: alles Bereite am Pass, älteste zuerst.
    static func waiterOrders(
        local: [LiveOrderMessage],
        online: [LiveOrderMessage]
    ) -> [LiveOrderMessage] {
        let merged = local.filter { $0.status == .ready }
            + online.filter { $0.status == .ready }
        return merged.sorted { $0.createdAt < $1.createdAt }
    }
}
