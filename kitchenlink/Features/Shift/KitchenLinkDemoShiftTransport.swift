import Foundation

/// KL-SHIFT-001: Sandbox-Demo der Betriebsschicht ohne Cloud.
///
/// Gleiche Rolle wie die übrigen Demo-Pfade hinter
/// `--kitchenlink-demo-tables`. Er rechnet bewusst genauso wie die Datenbank —
/// nur Bargeld erhöht den Kassenbestand, Trinkgeld in bar zählt mit, eine
/// zweite offene Schicht wird abgewiesen, die Z-Nummern laufen lückenlos —,
/// damit die Demo nichts anderes zeigt als der echte Weg.
///
/// **Es wird nichts abgeschlossen und kein Geld bewegt.**
actor KitchenLinkDemoShiftTransport: KitchenLinkShiftTransport {
    private struct State {
        var id: String
        var openedAt: Date
        var openingCashCents: Int
        var revenueCents = 0
        var tipCents = 0
        var cashPaymentsCents = 0
        var payoutCents = 0
        var expenseCents = 0
        var depositCents = 0
        var paymentCount = 0
    }

    private var open: State?
    private var closed: [KitchenLinkShift] = []
    private var nextZ = 1
    private var openKeys: Set<String> = []
    private var movementKeys: Set<String> = []

    /// Eine vorgeführte Schicht startet nicht bei null: sonst sieht man dem
    /// Bericht nicht an, wofür er gut ist.
    private let seedRevenue: Int
    private let seedTips: Int
    private let seedCash: Int

    init(seedRevenue: Int = 24_680, seedTips: Int = 1_850, seedCash: Int = 9_640) {
        self.seedRevenue = seedRevenue
        self.seedTips = seedTips
        self.seedCash = seedCash
    }

    private func totals(for state: State) -> KitchenLinkShiftTotals {
        let cardAmount = state.revenueCents - state.cashPaymentsCents + state.tipCents
        var methods: [KitchenLinkShiftMethodTotal] = []
        if state.cashPaymentsCents > 0 {
            methods.append(
                KitchenLinkShiftMethodTotal(
                    method: "cash",
                    amountCents: state.cashPaymentsCents - state.tipCents,
                    tipCents: state.tipCents,
                    count: max(state.paymentCount / 2, 1)
                )
            )
        }
        if cardAmount > 0 {
            methods.append(
                KitchenLinkShiftMethodTotal(
                    method: "card", amountCents: cardAmount, tipCents: 0,
                    count: max(state.paymentCount - state.paymentCount / 2, 1)
                )
            )
        }

        return KitchenLinkShiftTotals(
            revenueCents: state.revenueCents,
            tipCents: state.tipCents,
            refundedCents: 0,
            paymentCount: state.paymentCount,
            refundCount: 0,
            cashPaymentsCents: state.cashPaymentsCents,
            payoutCents: state.payoutCents,
            expenseCents: state.expenseCents,
            depositCents: state.depositCents,
            openingCashCents: state.openingCashCents,
            expectedCashCents: state.openingCashCents + state.cashPaymentsCents
                + state.depositCents - state.payoutCents - state.expenseCents,
            byMethod: methods.sorted { $0.amountCents > $1.amountCents }
        )
    }

    func openShift(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        openingCashCents: Int,
        idempotencyKey: String
    ) async throws {
        if openKeys.contains(idempotencyKey) { return }
        guard open == nil else {
            throw KitchenLinkCloudServiceError.server(
                status: 400, message: "shift_already_open: es ist bereits eine Schicht offen"
            )
        }
        openKeys.insert(idempotencyKey)
        open = State(
            id: "demo-shift-\(nextZ)",
            openedAt: Date(),
            openingCashCents: openingCashCents,
            revenueCents: seedRevenue,
            tipCents: seedTips,
            cashPaymentsCents: seedCash,
            paymentCount: 14
        )
    }

    func loadReport(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        shiftID: String?
    ) async throws -> KitchenLinkShiftReport {
        if let shiftID, let match = closed.first(where: { $0.id == shiftID }) {
            return KitchenLinkShiftReport(
                isOpen: false, shift: match, totals: .empty,
                unassignedCashCents: 0, openTableSessions: 0
            )
        }
        guard let state = open else { return .none }
        return KitchenLinkShiftReport(
            isOpen: true,
            shift: KitchenLinkShift(
                id: state.id,
                status: "open",
                openedAt: state.openedAt,
                closedAt: nil,
                zNumber: nil,
                openingCashCents: state.openingCashCents,
                countedCashCents: nil,
                expectedCashCents: nil,
                varianceCents: nil,
                closeNote: nil
            ),
            totals: totals(for: state),
            unassignedCashCents: 0,
            openTableSessions: 2
        )
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
        guard var state = open else {
            throw KitchenLinkCloudServiceError.server(
                status: 400, message: "cash_no_open_shift: es ist keine Schicht offen"
            )
        }
        if movementKeys.contains(idempotencyKey) { return }
        movementKeys.insert(idempotencyKey)

        switch kind {
        case .payout: state.payoutCents += amountCents
        case .expense: state.expenseCents += amountCents
        case .deposit: state.depositCents += amountCents
        }
        open = state
    }

    func closeShift(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        countedCashCents: Int,
        note: String
    ) async throws -> KitchenLinkShiftClose {
        guard let state = open else {
            throw KitchenLinkCloudServiceError.server(
                status: 400, message: "shift_none_open: es ist keine Schicht offen"
            )
        }
        let summed = totals(for: state)
        let expected = summed.expectedCashCents
        let z = nextZ

        closed.insert(
            KitchenLinkShift(
                id: state.id,
                status: "closed",
                openedAt: state.openedAt,
                closedAt: Date(),
                zNumber: z,
                openingCashCents: state.openingCashCents,
                countedCashCents: countedCashCents,
                expectedCashCents: expected,
                varianceCents: countedCashCents - expected,
                closeNote: note.isEmpty ? nil : note
            ),
            at: 0
        )
        nextZ += 1
        open = nil
        movementKeys.removeAll()

        return KitchenLinkShiftClose(
            shiftID: state.id,
            zNumber: z,
            countedCashCents: countedCashCents,
            expectedCashCents: expected,
            varianceCents: countedCashCents - expected,
            totals: summed
        )
    }

    func recentShifts(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        limit: Int
    ) async throws -> [KitchenLinkShift] {
        Array(closed.prefix(limit))
    }
}
