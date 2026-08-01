import Foundation

/// KL-PAY-001: Sandbox-Demo des Kassierens ohne Cloud.
///
/// Gleiche Rolle wie die Demo-Seeder von `Heute`, `Küche` und `Bestand`
/// (Launch-Argument `--kitchenlink-demo-tables`): der Ablauf bleibt vorführ-
/// und prüfbar, ohne dass eine Instanz erreichbar sein muss. Er rechnet
/// bewusst genauso wie die Datenbank — Auswahl bestimmt den Betrag, eine
/// bezahlte Position ist gesperrt, ein Storno gibt sie wieder frei —, damit die
/// Demo nicht etwas anderes zeigt als der echte Weg.
///
/// **Es wird nichts gebucht und nichts bezahlt.**
actor KitchenLinkDemoCheckTransport: KitchenLinkCheckTransport {
    private var items: [KitchenLinkCheckItem]
    private var paidCents = 0
    private var tipCents = 0
    private var itemsByPayment: [String: [String]] = [:]
    private var sessionOpen = true

    init(items: [KitchenLinkCheckItem]? = nil) {
        self.items = items ?? [
            KitchenLinkCheckItem(
                id: "demo-1", name: "Kürbissuppe", quantity: 2,
                unitPriceCents: 690, lineTotalCents: 1380, paid: false
            ),
            KitchenLinkCheckItem(
                id: "demo-2", name: "Wiener Schnitzel", quantity: 1,
                unitPriceCents: 2180, lineTotalCents: 2180, paid: false
            ),
            KitchenLinkCheckItem(
                id: "demo-3", name: "Hauslimonade Holunder", quantity: 2,
                unitPriceCents: 450, lineTotalCents: 900, paid: false
            )
        ]
    }

    func loadCheck(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        tableID: String
    ) async throws -> KitchenLinkCheck {
        let total = items.reduce(0) { $0 + $1.lineTotalCents }
        return KitchenLinkCheck(
            tableSessionID: sessionOpen ? "demo-session" : nil,
            totalCents: total,
            paidCents: paidCents,
            tipCents: tipCents,
            openCents: max(total - paidCents, 0),
            items: items
        )
    }

    func recordPayment(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        tableSessionID: String,
        method: KitchenLinkPaymentMethod,
        idempotencyKey: String,
        tipCents newTip: Int,
        orderItemIDs: [String],
        amountCents: Int?,
        providerReference: String?
    ) async throws -> KitchenLinkPaymentReceipt {
        let total = items.reduce(0) { $0 + $1.lineTotalCents }
        let selected = orderItemIDs.isEmpty
            ? items.filter { !$0.paid }.map(\.id)
            : orderItemIDs

        if selected.contains(where: { id in items.contains { $0.id == id && $0.paid } }) {
            throw KitchenLinkCloudServiceError.server(
                status: 409,
                message: "payment_item_unavailable: Position ist bereits bezahlt"
            )
        }

        let amount = items
            .filter { selected.contains($0.id) }
            .reduce(0) { $0 + $1.lineTotalCents }

        items = items.map { line in
            guard selected.contains(line.id) else { return line }
            return KitchenLinkCheckItem(
                id: line.id,
                name: line.name,
                quantity: line.quantity,
                unitPriceCents: line.unitPriceCents,
                lineTotalCents: line.lineTotalCents,
                paid: true
            )
        }
        paidCents += amount
        tipCents += newTip
        let paymentID = "demo-payment-\(itemsByPayment.count + 1)"
        itemsByPayment[paymentID] = selected
        let closed = paidCents >= total
        sessionOpen = !closed

        return KitchenLinkPaymentReceipt(
            paymentID: paymentID,
            amountCents: amount,
            tipCents: newTip,
            providerReference: providerReference
                ?? "sandbox-demo-\(UUID().uuidString.prefix(8).lowercased())",
            openCents: max(total - paidCents, 0),
            sessionClosed: closed,
            replayed: false
        )
    }

    func refundPayment(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        paymentID: String,
        reason: String,
        overrideToken: String?
    ) async throws {
        // KL-ROLE-002: Eine mitgeschickte Freigabe gilt auch in der Demo genau
        // einmal — sonst zeigte die Demo eine Zusage, die der echte Weg nicht
        // einhält.
        if let overrideToken, !overrideToken.isEmpty {
            try await KitchenLinkDemoManagerPinTransport.shared.consume(
                token: overrideToken, permission: .paymentsRefund
            )
        }
        guard let released = itemsByPayment.removeValue(forKey: paymentID) else { return }
        let amount = items
            .filter { released.contains($0.id) }
            .reduce(0) { $0 + $1.lineTotalCents }
        items = items.map { line in
            guard released.contains(line.id) else { return line }
            return KitchenLinkCheckItem(
                id: line.id,
                name: line.name,
                quantity: line.quantity,
                unitPriceCents: line.unitPriceCents,
                lineTotalCents: line.lineTotalCents,
                paid: false
            )
        }
        paidCents = max(paidCents - amount, 0)
        sessionOpen = true
    }
}
