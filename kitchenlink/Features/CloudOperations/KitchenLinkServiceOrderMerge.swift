import Foundation

/// Zusammenführung von Online- und lokalen Bestellungen für die eine
/// Service-Liste (KL-CLOUD-001, erweitert um KL-TABLE-002).
///
/// Alle Quellen gelten als angenommen: Gastbestellungen aus dem Gast-Web
/// (Blueprint §6.3, automatische Annahme ist der Standard), Bestellungen des
/// lokalen Hubs und die vom Kellner aufgenommenen. Sie unterscheiden sich nur
/// im Startstatus — der Hub setzt `preparing`, Gast-Web und Kellner `pending` —
/// und dürfen deshalb nicht unterschiedlich gefiltert werden. Vorher fiel eine
/// Kellnerbestellung durch: sie startet `pending`, die lokale Liste zeigte aber
/// nur `preparing`.
enum KitchenLinkServiceOrderMerge {
    static let kitchenStatuses: Set<OrderLifecycleStatus> = [
        .pending, .accepted, .preparing
    ]

    /// Küche: alles, was noch zubereitet werden muss, älteste zuerst.
    static func kitchenOrders(
        local: [LiveOrderMessage],
        online: [LiveOrderMessage]
    ) -> [LiveOrderMessage] {
        merge(local: local, online: online) { kitchenStatuses.contains($0.status) }
    }

    /// Kellner: alles Bereite am Pass, älteste zuerst.
    static func waiterOrders(
        local: [LiveOrderMessage],
        online: [LiveOrderMessage]
    ) -> [LiveOrderMessage] {
        merge(local: local, online: online) { $0.status == .ready }
    }

    /// Eine lokal aufgenommene Bestellung taucht nach der Cloud-Synchronisation
    /// ein zweites Mal auf — dieselbe ID, zwei Quellen. Die Online-Fassung
    /// gewinnt: für sie funktioniert der Status-Schreibweg über die RPC, und
    /// sie ist der Stand, den auch andere Geräte sehen.
    private static func merge(
        local: [LiveOrderMessage],
        online: [LiveOrderMessage],
        matching predicate: (LiveOrderMessage) -> Bool
    ) -> [LiveOrderMessage] {
        var byID: [String: LiveOrderMessage] = [:]
        for order in local where predicate(order) {
            byID[order.id] = order
        }
        for order in online where predicate(order) {
            byID[order.id] = order
        }
        return byID.values.sorted { left, right in
            left.createdAt == right.createdAt
                ? left.id < right.id
                : left.createdAt < right.createdAt
        }
    }
}
