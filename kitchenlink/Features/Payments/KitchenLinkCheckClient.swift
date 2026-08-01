import Foundation

/// KL-PAY-001: Rechnung und Zahlung gegen die Sandbox-Instanz.
///
/// Alle drei Wege laufen über die staff-gated RPCs aus Migration
/// `20260731100000_sandbox_payments.sql`. Der **Betrag wird nie vom Gerät
/// bestimmt**: bei getrenntem Zahlen schickt die App die gewählten Positionen,
/// die Summe rechnet die Datenbank. Das ist dieselbe Regel wie bei der
/// Gastbestellung und der einzige Grund, warum zwei gleichzeitig kassierende
/// Geräte nicht denselben Gang zweimal abrechnen können.

struct KitchenLinkCheckItem: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let quantity: Int
    let unitPriceCents: Int
    let lineTotalCents: Int
    let paid: Bool

    var quantityPrefix: String { "\(quantity)× " }
}

struct KitchenLinkCheck: Equatable, Sendable {
    let tableSessionID: String?
    let totalCents: Int
    let paidCents: Int
    let tipCents: Int
    let openCents: Int
    let items: [KitchenLinkCheckItem]

    static let empty = KitchenLinkCheck(
        tableSessionID: nil,
        totalCents: 0,
        paidCents: 0,
        tipCents: 0,
        openCents: 0,
        items: []
    )

    var isSettled: Bool { tableSessionID != nil && openCents == 0 }
    var hasOpenItems: Bool { items.contains { !$0.paid } }

    /// Rohe RPC-Antwort in das Anzeigemodell. Eine Zeile, die sich nicht lesen
    /// lässt, wird verworfen statt geraten — eine erfundene Rechnungsposition
    /// wäre schlimmer als eine fehlende.
    static func decode(_ data: Data) throws -> KitchenLinkCheck {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        let rawItems = root["items"] as? [[String: Any]] ?? []
        let items: [KitchenLinkCheckItem] = rawItems.compactMap { row in
            guard let id = row["order_item_id"] as? String,
                  let name = row["name"] as? String,
                  let quantity = row["quantity"] as? Int,
                  let unitPrice = row["unit_price_cents"] as? Int,
                  let lineTotal = row["line_total_cents"] as? Int else {
                return nil
            }
            return KitchenLinkCheckItem(
                id: id,
                name: name,
                quantity: quantity,
                unitPriceCents: unitPrice,
                lineTotalCents: lineTotal,
                paid: row["paid"] as? Bool ?? false
            )
        }
        return KitchenLinkCheck(
            tableSessionID: root["table_session_id"] as? String,
            totalCents: root["total_cents"] as? Int ?? 0,
            paidCents: root["paid_cents"] as? Int ?? 0,
            tipCents: root["tip_cents"] as? Int ?? 0,
            openCents: root["open_cents"] as? Int ?? 0,
            items: items
        )
    }
}

struct KitchenLinkPaymentReceipt: Equatable, Sendable {
    let paymentID: String
    let amountCents: Int
    let tipCents: Int
    let providerReference: String
    let openCents: Int
    let sessionClosed: Bool
    let replayed: Bool

    static func decode(_ data: Data) throws -> KitchenLinkPaymentReceipt {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let paymentID = root["payment_id"] as? String else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        return KitchenLinkPaymentReceipt(
            paymentID: paymentID,
            amountCents: root["amount_cents"] as? Int ?? 0,
            tipCents: root["tip_cents"] as? Int ?? 0,
            providerReference: root["provider_reference"] as? String ?? "",
            openCents: root["open_cents"] as? Int ?? 0,
            sessionClosed: root["session_closed"] as? Bool ?? false,
            replayed: root["replayed"] as? Bool ?? false
        )
    }
}

protocol KitchenLinkCheckTransport: Sendable {
    func loadCheck(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        tableID: String
    ) async throws -> KitchenLinkCheck

    func recordPayment(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        tableSessionID: String,
        method: KitchenLinkPaymentMethod,
        idempotencyKey: String,
        tipCents: Int,
        orderItemIDs: [String],
        amountCents: Int?,
        providerReference: String?
    ) async throws -> KitchenLinkPaymentReceipt

    /// KL-ROLE-002: `overrideToken` ist die einmalige Freigabe einer
    /// Führungskraft. Wer `payments.refund` selbst trägt, schickt keine.
    func refundPayment(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        paymentID: String,
        reason: String,
        overrideToken: String?
    ) async throws
}

extension URLSessionKitchenLinkCloudTransport: KitchenLinkCheckTransport {
    func loadCheck(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        tableID: String
    ) async throws -> KitchenLinkCheck {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_table_id: String
        }
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_table_check",
            bodyData: try JSONEncoder().encode(
                Body(p_venue_slug: venueSlug, p_table_id: tableID)
            )
        )
        return try KitchenLinkCheck.decode(data)
    }

    func recordPayment(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        tableSessionID: String,
        method: KitchenLinkPaymentMethod,
        idempotencyKey: String,
        tipCents: Int,
        orderItemIDs: [String],
        amountCents: Int?,
        providerReference: String?
    ) async throws -> KitchenLinkPaymentReceipt {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_table_session_id: String
            let p_method: String
            let p_idempotency_key: String
            let p_tip_cents: Int
            let p_order_item_ids: [String]?
            let p_amount_cents: Int?
            let p_provider_reference: String?
        }
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_record_payment",
            bodyData: try JSONEncoder().encode(
                Body(
                    p_venue_slug: venueSlug,
                    p_table_session_id: tableSessionID,
                    p_method: method.rawValue,
                    p_idempotency_key: idempotencyKey,
                    p_tip_cents: tipCents,
                    p_order_item_ids: orderItemIDs.isEmpty ? nil : orderItemIDs,
                    p_amount_cents: amountCents,
                    p_provider_reference: providerReference
                )
            )
        )
        return try KitchenLinkPaymentReceipt.decode(data)
    }

    func refundPayment(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        paymentID: String,
        reason: String,
        overrideToken: String?
    ) async throws {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_payment_id: String
            let p_reason: String
            let p_override_token: String?
        }
        _ = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_refund_payment",
            bodyData: try JSONEncoder().encode(
                Body(
                    p_venue_slug: venueSlug,
                    p_payment_id: paymentID,
                    p_reason: reason,
                    p_override_token: overrideToken
                )
            )
        )
    }
}
