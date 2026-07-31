import Foundation

/// KL-SHIFT-001: Betriebsschicht und Kassenabschluss gegen die Sandbox-Instanz.
///
/// Alle Wege laufen über die staff-gated RPCs aus Migration
/// `20260731200000_business_shift.sql`. Wie beim Kassieren gilt: **die App
/// rechnet nicht mit.** Der erwartete Bargeldbestand und die Abweichung kommen
/// aus der Datenbank, weil nur sie den Stand kennt, den alle Geräte der Venue
/// teilen. Die App zählt nur, was der Betreiber in der Schublade findet.

enum KitchenLinkCashMovementKind: String, CaseIterable, Sendable {
    /// Geld verlässt die Kasse in den Tresor.
    case payout
    /// Bar bezahlte Rechnung, etwa der Gemüselieferant.
    case expense
    /// Wechselgeld wird nachgelegt.
    case deposit

    var label: String {
        switch self {
        case .payout: "Entnahme"
        case .expense: "Ausgabe"
        case .deposit: "Einlage"
        }
    }

    var systemImage: String {
        switch self {
        case .payout: "arrow.up.circle"
        case .expense: "cart"
        case .deposit: "arrow.down.circle"
        }
    }

    /// Vorzeichen in der Kassenrechnung.
    var increasesCash: Bool { self == .deposit }
}

struct KitchenLinkShiftMethodTotal: Identifiable, Equatable, Sendable {
    let method: String
    let amountCents: Int
    let tipCents: Int
    let count: Int

    var id: String { method }

    var label: String {
        switch method {
        case "cash": "Bar"
        case "card": "Karte"
        case "tap_to_pay": "Tap to Pay"
        case "voucher": "Gutschein"
        case "online": "Online"
        default: method
        }
    }
}

struct KitchenLinkShiftTotals: Equatable, Sendable {
    let revenueCents: Int
    let tipCents: Int
    let refundedCents: Int
    let paymentCount: Int
    let refundCount: Int
    let cashPaymentsCents: Int
    let payoutCents: Int
    let expenseCents: Int
    let depositCents: Int
    let openingCashCents: Int
    let expectedCashCents: Int
    let byMethod: [KitchenLinkShiftMethodTotal]

    static let empty = KitchenLinkShiftTotals(
        revenueCents: 0, tipCents: 0, refundedCents: 0, paymentCount: 0, refundCount: 0,
        cashPaymentsCents: 0, payoutCents: 0, expenseCents: 0, depositCents: 0,
        openingCashCents: 0, expectedCashCents: 0, byMethod: []
    )

    static func decode(_ root: [String: Any]) -> KitchenLinkShiftTotals {
        let rawMethods = root["by_method"] as? [String: Any] ?? [:]
        let methods: [KitchenLinkShiftMethodTotal] = rawMethods.compactMap { key, value in
            guard let row = value as? [String: Any] else { return nil }
            return KitchenLinkShiftMethodTotal(
                method: key,
                amountCents: row["amount_cents"] as? Int ?? 0,
                tipCents: row["tip_cents"] as? Int ?? 0,
                count: row["count"] as? Int ?? 0
            )
        }
        .sorted { $0.amountCents > $1.amountCents }

        return KitchenLinkShiftTotals(
            revenueCents: root["revenue_cents"] as? Int ?? 0,
            tipCents: root["tip_cents"] as? Int ?? 0,
            refundedCents: root["refunded_cents"] as? Int ?? 0,
            paymentCount: root["payment_count"] as? Int ?? 0,
            refundCount: root["refund_count"] as? Int ?? 0,
            cashPaymentsCents: root["cash_payments_cents"] as? Int ?? 0,
            payoutCents: root["payout_cents"] as? Int ?? 0,
            expenseCents: root["expense_cents"] as? Int ?? 0,
            depositCents: root["deposit_cents"] as? Int ?? 0,
            openingCashCents: root["opening_cash_cents"] as? Int ?? 0,
            expectedCashCents: root["expected_cash_cents"] as? Int ?? 0,
            byMethod: methods
        )
    }
}

struct KitchenLinkShift: Identifiable, Equatable, Sendable {
    let id: String
    let status: String
    let openedAt: Date?
    let closedAt: Date?
    let zNumber: Int?
    let openingCashCents: Int
    let countedCashCents: Int?
    let expectedCashCents: Int?
    let varianceCents: Int?
    let closeNote: String?

    var isOpen: Bool { status == "open" }

    static func decode(_ root: [String: Any]) -> KitchenLinkShift? {
        guard let id = root["id"] as? String else { return nil }
        return KitchenLinkShift(
            id: id,
            status: root["status"] as? String ?? "open",
            openedAt: (root["opened_at"] as? String).flatMap(KitchenLinkCloudTimestamp.parse),
            closedAt: (root["closed_at"] as? String).flatMap(KitchenLinkCloudTimestamp.parse),
            zNumber: root["z_number"] as? Int,
            openingCashCents: root["opening_cash_cents"] as? Int ?? 0,
            countedCashCents: root["counted_cash_cents"] as? Int,
            expectedCashCents: root["expected_cash_cents"] as? Int,
            varianceCents: root["variance_cents"] as? Int,
            closeNote: root["close_note"] as? String
        )
    }
}

struct KitchenLinkShiftReport: Equatable, Sendable {
    let isOpen: Bool
    let shift: KitchenLinkShift?
    let totals: KitchenLinkShiftTotals
    /// Bargeld, das seit Schichtbeginn ohne offene Schicht angenommen wurde.
    /// Sichtbar statt still geschluckt — sonst fehlt es beim Zählen unerklärt.
    let unassignedCashCents: Int
    let openTableSessions: Int

    static let none = KitchenLinkShiftReport(
        isOpen: false, shift: nil, totals: .empty,
        unassignedCashCents: 0, openTableSessions: 0
    )

    static func decode(_ data: Data) throws -> KitchenLinkShiftReport {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        let shift = (root["shift"] as? [String: Any]).flatMap(KitchenLinkShift.decode)
        return KitchenLinkShiftReport(
            isOpen: root["open"] as? Bool ?? false,
            shift: shift,
            totals: KitchenLinkShiftTotals.decode(root["totals"] as? [String: Any] ?? [:]),
            unassignedCashCents: root["unassigned_cash_cents"] as? Int ?? 0,
            openTableSessions: root["open_table_sessions"] as? Int ?? 0
        )
    }
}

struct KitchenLinkShiftClose: Equatable, Sendable {
    let shiftID: String
    let zNumber: Int
    let countedCashCents: Int
    let expectedCashCents: Int
    /// Positiv heißt Überschuss, negativ heißt Fehlbetrag.
    let varianceCents: Int
    let totals: KitchenLinkShiftTotals

    var isBalanced: Bool { varianceCents == 0 }

    static func decode(_ data: Data) throws -> KitchenLinkShiftClose {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let shiftID = root["shift_id"] as? String else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        return KitchenLinkShiftClose(
            shiftID: shiftID,
            zNumber: root["z_number"] as? Int ?? 0,
            countedCashCents: root["counted_cash_cents"] as? Int ?? 0,
            expectedCashCents: root["expected_cash_cents"] as? Int ?? 0,
            varianceCents: root["variance_cents"] as? Int ?? 0,
            totals: KitchenLinkShiftTotals.decode(root["totals"] as? [String: Any] ?? [:])
        )
    }
}

protocol KitchenLinkShiftTransport: Sendable {
    func openShift(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        openingCashCents: Int,
        idempotencyKey: String
    ) async throws

    func loadReport(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        shiftID: String?
    ) async throws -> KitchenLinkShiftReport

    func recordCashMovement(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        kind: KitchenLinkCashMovementKind,
        amountCents: Int,
        reason: String,
        idempotencyKey: String
    ) async throws

    func closeShift(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        countedCashCents: Int,
        note: String
    ) async throws -> KitchenLinkShiftClose

    func recentShifts(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        limit: Int
    ) async throws -> [KitchenLinkShift]
}

extension URLSessionKitchenLinkCloudTransport: KitchenLinkShiftTransport {
    func openShift(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        openingCashCents: Int,
        idempotencyKey: String
    ) async throws {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_opening_cash_cents: Int
            let p_idempotency_key: String
        }
        _ = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_open_shift",
            bodyData: try JSONEncoder().encode(
                Body(
                    p_venue_slug: venueSlug,
                    p_opening_cash_cents: openingCashCents,
                    p_idempotency_key: idempotencyKey
                )
            )
        )
    }

    func loadReport(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        shiftID: String?
    ) async throws -> KitchenLinkShiftReport {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_shift_id: String?
        }
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_shift_report",
            bodyData: try JSONEncoder().encode(
                Body(p_venue_slug: venueSlug, p_shift_id: shiftID)
            )
        )
        return try KitchenLinkShiftReport.decode(data)
    }

    func recordCashMovement(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        kind: KitchenLinkCashMovementKind,
        amountCents: Int,
        reason: String,
        idempotencyKey: String
    ) async throws {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_kind: String
            let p_amount_cents: Int
            let p_idempotency_key: String
            let p_reason: String?
        }
        _ = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_record_cash_movement",
            bodyData: try JSONEncoder().encode(
                Body(
                    p_venue_slug: venueSlug,
                    p_kind: kind.rawValue,
                    p_amount_cents: amountCents,
                    p_idempotency_key: idempotencyKey,
                    p_reason: reason.isEmpty ? nil : reason
                )
            )
        )
    }

    func closeShift(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        countedCashCents: Int,
        note: String
    ) async throws -> KitchenLinkShiftClose {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_counted_cash_cents: Int
            let p_note: String?
        }
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_close_shift",
            bodyData: try JSONEncoder().encode(
                Body(
                    p_venue_slug: venueSlug,
                    p_counted_cash_cents: countedCashCents,
                    p_note: note.isEmpty ? nil : note
                )
            )
        )
        return try KitchenLinkShiftClose.decode(data)
    }

    func recentShifts(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        limit: Int
    ) async throws -> [KitchenLinkShift] {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_limit: Int
        }
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_recent_shifts",
            bodyData: try JSONEncoder().encode(
                Body(p_venue_slug: venueSlug, p_limit: limit)
            )
        )
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        return rows.compactMap(KitchenLinkShift.decode)
    }
}
