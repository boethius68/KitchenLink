import Foundation

/// KL-LEAVE-001: Sandbox-Demo der Abwesenheiten ohne Cloud.
///
/// Er bildet die **Asymmetrie** der Datenbank nach: ein Antrag blockiert die
/// Planung noch nicht, eine Genehmigung schon — und eine Genehmigung auf
/// bereits geplante Schichten wird trotzdem erteilt und meldet sie nur.
///
/// **Es wird kein Urlaub genehmigt.**
actor KitchenLinkDemoLeaveTransport: KitchenLinkLeaveTransport {
    private var leaves: [KitchenLinkLeave]
    private let meID = "demo-me"

    /// Wie viele geplante Schichten eine Abwesenheit trifft. Im Demo fest
    /// hinterlegt statt aus dem Plan gerechnet — die beiden Transporte kennen
    /// einander nicht, und die Zahl soll trotzdem etwas zeigen.
    private var conflicts: [String: Int] = ["demo-leave-2": 1]

    init(seeded: Bool = true) {
        guard seeded else {
            leaves = []
            return
        }
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        func day(_ offset: Int) -> Date {
            cal.date(byAdding: .day, value: offset, to: today) ?? today
        }

        leaves = [
            // Eigener Antrag, noch offen — zurückziehbar.
            KitchenLinkLeave(
                id: "demo-leave-1", userID: "demo-me", email: "du@restaurant.de",
                roleName: "Inhaber", startsAt: day(20), endsAt: day(27),
                kind: .vacation, status: .requested, reason: "Sommerurlaub",
                reviewNote: nil, conflictingShifts: 0
            ),
            // Offener Antrag einer Kollegin, der auf eine geplante Schicht
            // fällt — der Fall, für den die Zahl da ist.
            KitchenLinkLeave(
                id: "demo-leave-2", userID: "demo-3", email: "jonas@restaurant.de",
                roleName: "Service", startsAt: day(1), endsAt: day(3),
                kind: .sick, status: .requested, reason: "Grippe",
                reviewNote: nil, conflictingShifts: 1
            ),
            KitchenLinkLeave(
                id: "demo-leave-3", userID: "demo-4", email: "mira@restaurant.de",
                roleName: "Küche", startsAt: day(10), endsAt: day(14),
                kind: .training, status: .approved, reason: nil,
                reviewNote: "Viel Erfolg", conflictingShifts: 0
            )
        ]
    }

    private func fail(_ code: String) -> KitchenLinkCloudServiceError {
        KitchenLinkCloudServiceError.server(status: 400, message: code)
    }

    private func overlapsApproved(userID: String, from: Date, to: Date) -> Bool {
        leaves.contains {
            $0.userID == userID && $0.status == .approved
                && $0.startsAt < to && from < $0.endsAt
        }
    }

    func loadMyLeaves(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> [KitchenLinkLeave] {
        leaves.filter { $0.userID == meID }.sorted { $0.startsAt > $1.startsAt }
    }

    func loadVenueLeaves(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        onlyOpen: Bool
    ) async throws -> [KitchenLinkLeave] {
        leaves
            .filter { !onlyOpen || $0.status.isOpen }
            .sorted { $0.startsAt < $1.startsAt }
    }

    func requestLeave(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        startsAt: Date,
        endsAt: Date,
        kind: KitchenLinkLeaveKind,
        reason: String?
    ) async throws {
        guard endsAt > startsAt else { throw fail("leave_invalid_range") }
        guard !overlapsApproved(userID: meID, from: startsAt, to: endsAt) else {
            throw fail("leave_already_approved")
        }
        leaves.append(
            KitchenLinkLeave(
                id: "demo-leave-\(leaves.count + 1)", userID: meID,
                email: "du@restaurant.de", roleName: "Inhaber",
                startsAt: startsAt, endsAt: endsAt, kind: kind,
                status: .requested, reason: reason, reviewNote: nil,
                conflictingShifts: 0
            )
        )
    }

    func cancelLeave(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        leaveID: String
    ) async throws {
        guard let index = leaves.firstIndex(where: { $0.id == leaveID }) else {
            throw fail("leave_unknown")
        }
        guard leaves[index].userID == meID else { throw fail("leave_not_yours") }
        guard leaves[index].status.isOpen else { throw fail("leave_already_decided") }
        leaves[index] = replacing(leaves[index], status: .cancelled, note: nil)
    }

    func reviewLeave(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        leaveID: String,
        approve: Bool,
        note: String?
    ) async throws -> KitchenLinkLeaveDecision {
        guard let index = leaves.firstIndex(where: { $0.id == leaveID }) else {
            throw fail("leave_unknown")
        }
        guard leaves[index].status.isOpen else { throw fail("leave_already_decided") }

        let leave = leaves[index]
        if approve, overlapsApproved(userID: leave.userID ?? "", from: leave.startsAt,
                                     to: leave.endsAt) {
            throw fail("leave_overlaps_approved")
        }

        leaves[index] = replacing(leave, status: approve ? .approved : .rejected, note: note)
        return KitchenLinkLeaveDecision(
            status: approve ? .approved : .rejected,
            // Nur eine Genehmigung meldet Kollisionen; eine Ablehnung aendert
            // am Plan nichts.
            conflictingShiftCount: approve ? (conflicts[leaveID] ?? 0) : 0
        )
    }

    private func replacing(
        _ leave: KitchenLinkLeave,
        status: KitchenLinkLeaveStatus,
        note: String?
    ) -> KitchenLinkLeave {
        KitchenLinkLeave(
            id: leave.id, userID: leave.userID, email: leave.email,
            roleName: leave.roleName, startsAt: leave.startsAt, endsAt: leave.endsAt,
            kind: leave.kind, status: status, reason: leave.reason,
            reviewNote: note ?? leave.reviewNote,
            conflictingShifts: leave.conflictingShifts
        )
    }
}
