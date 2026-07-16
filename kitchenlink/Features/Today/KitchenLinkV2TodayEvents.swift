import Foundation

/// One line in the V2 `Heute` work list, derived from the existing sandbox
/// order domain. Operation stays a shape, urgency stays a color, and the verb
/// stays visible plain text.
struct KitchenLinkV2TodayEvent: Identifiable, Equatable {
    enum TrailingValue: Equatable {
        case elapsed(TimeInterval)
        case overdue(TimeInterval)
        case amount(cents: Int)

        var text: String {
            switch self {
            case .elapsed(let interval):
                return KitchenLinkV2TimeText.elapsed(interval)
            case .overdue(let interval):
                return "+" + KitchenLinkV2TimeText.elapsed(interval)
            case .amount(let cents):
                return KitchenLinkV2AmountText.euro(cents: cents)
            }
        }
    }

    let id: String
    let status: KitchenLinkV2Status
    let title: String
    let detail: String
    let trailing: TrailingValue
    let orderStatus: OrderLifecycleStatus
    let createdAt: Date

    var nextActionTitle: String? {
        orderStatus.primaryActionTitle
    }
}

enum KitchenLinkV2TodayEventBuilder {
    /// An accepted or preparing order older than this needs attention.
    static let kitchenWaitThreshold: TimeInterval = 6 * 60

    /// Derives the work list from sandbox orders, most urgent first.
    /// Canceled orders carry no next action and are excluded.
    static func events(
        from orders: [LiveOrderMessage],
        now: Date = Date()
    ) -> [KitchenLinkV2TodayEvent] {
        orders
            .compactMap { event(from: $0, now: now) }
            .sorted { lhs, rhs in
                let lhsRank = urgencyRank(lhs.status.urgency)
                let rhsRank = urgencyRank(rhs.status.urgency)
                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }
                return lhs.createdAt < rhs.createdAt
            }
    }

    /// The one event the persistent primary action should advance next:
    /// the most urgent event that still has a lifecycle transition.
    static func nextAction(
        in events: [KitchenLinkV2TodayEvent]
    ) -> KitchenLinkV2TodayEvent? {
        events.first { $0.nextActionTitle != nil }
    }

    static func event(
        from order: LiveOrderMessage,
        now: Date = Date()
    ) -> KitchenLinkV2TodayEvent? {
        let age = now.timeIntervalSince(order.createdAt)
        let place = placeTitle(for: order)

        let status: KitchenLinkV2Status
        let detail: String
        let trailing: KitchenLinkV2TodayEvent.TrailingValue

        switch order.status {
        case .pending:
            status = KitchenLinkV2Status(
                operation: .order,
                urgency: .fresh,
                verb: "neue Bestellung"
            )
            detail = "frisch eingegangen"
            trailing = .elapsed(age)

        case .accepted, .preparing:
            let isLate = age > kitchenWaitThreshold
            let verb = order.status == .accepted ? "angenommen" : "in Zubereitung"
            status = KitchenLinkV2Status(
                operation: .order,
                urgency: isLate ? .waiting : .neutral,
                verb: isLate ? "Küche wartet" : verb
            )
            detail = isLate ? "über Richtzeit" : "läuft planmäßig"
            trailing = isLate ? .overdue(age - kitchenWaitThreshold) : .elapsed(age)

        case .ready:
            status = KitchenLinkV2Status(
                operation: .order,
                urgency: .fresh,
                verb: "bereit zu servieren"
            )
            detail = "Abholung am Pass"
            trailing = .elapsed(age)

        case .served:
            // The sandbox has no payment domain yet: a served order is an
            // open payment task. Open payment stays neutral, never red.
            status = KitchenLinkV2Status(
                operation: .payment,
                urgency: .neutral,
                verb: "Zahlung offen"
            )
            detail = "neutral · kein Alarm"
            trailing = .amount(cents: order.totalCents)

        case .canceled:
            return nil
        }

        return KitchenLinkV2TodayEvent(
            id: order.id,
            status: status,
            title: "\(place) · \(status.verb)",
            detail: detail,
            trailing: trailing,
            orderStatus: order.status,
            createdAt: order.createdAt
        )
    }

    static func placeTitle(for order: LiveOrderMessage) -> String {
        if let tableLabel = order.tableLabel, !tableLabel.isEmpty {
            return "Tisch \(tableLabel)"
        }
        return order.serviceMode?.title ?? "Bestellung"
    }

    private static func urgencyRank(_ urgency: KitchenLinkV2Urgency) -> Int {
        switch urgency {
        case .critical:
            return 0
        case .waiting:
            return 1
        case .fresh:
            return 2
        case .neutral:
            return 3
        }
    }
}

enum KitchenLinkV2TimeText {
    static func elapsed(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes):" + String(format: "%02d", seconds)
    }
}

enum KitchenLinkV2AmountText {
    static func euro(cents: Int) -> String {
        let sign = cents < 0 ? "-" : ""
        let magnitude = abs(cents)
        return "€ \(sign)\(magnitude / 100)," + String(format: "%02d", magnitude % 100)
    }
}
