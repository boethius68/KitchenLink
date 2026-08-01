import Foundation

/// KL-PLAN-001: Sandbox-Demo des Dienstplans ohne Cloud.
///
/// Er verhält sich wie die Datenbank — überlappende Schichten derselben Person
/// werden abgewiesen, eine abgelehnte gibt den Zeitraum wieder frei, ein
/// Entwurf ist für den Betroffenen unsichtbar, und das Verschieben einer
/// angenommenen Schicht hebt die Zusage auf —, damit die Demo nichts anderes
/// zeigt als der echte Weg.
///
/// **Es wird niemand eingeteilt.**
actor KitchenLinkDemoScheduleTransport: KitchenLinkScheduleTransport {
    private var shifts: [KitchenLinkPlannedShift]
    private let meID = "demo-me"

    init(seeded: Bool = true) {
        guard seeded else {
            shifts = []
            return
        }
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let today = cal.startOfDay(for: Date())
        let weekStart = cal.dateInterval(of: .weekOfYear, for: today)?.start ?? today

        // Zwei Anker, weil der Bildschirm zwei Fenster hat: „Meine Schichten"
        // zeigt die **kommenden** (ab jetzt), die Wochenansicht die
        // **Kalenderwoche**. Hinge alles an „heute", wäre die Woche an einem
        // Freitag halb leer — und hinge alles am Wochenbeginn, wären die
        // eigenen Schichten ab Mittwoch Vergangenheit.
        func fromToday(_ dayOffset: Int, _ hour: Int) -> Date {
            cal.date(byAdding: .hour, value: hour,
                     to: cal.date(byAdding: .day, value: dayOffset, to: today) ?? today) ?? today
        }
        func inWeek(_ dayOffset: Int, _ hour: Int) -> Date {
            cal.date(byAdding: .hour, value: hour,
                     to: cal.date(byAdding: .day, value: dayOffset, to: weekStart) ?? weekStart)
                ?? weekStart
        }

        shifts = [
            // Eigene Schicht, die auf eine Antwort wartet — der einzige
            // Eintrag auf diesem Bildschirm, der etwas von einem will.
            KitchenLinkPlannedShift(
                id: "demo-plan-1", userID: "demo-me", email: "du@restaurant.de",
                roleName: "Inhaber", startsAt: fromToday(1, 17), endsAt: fromToday(1, 23),
                area: "Gastraum", station: nil, status: .published,
                note: "Abenddienst", declineReason: nil
            ),
            KitchenLinkPlannedShift(
                id: "demo-plan-2", userID: "demo-me", email: "du@restaurant.de",
                roleName: "Inhaber", startsAt: fromToday(3, 11), endsAt: fromToday(3, 16),
                area: "Terrasse", station: nil, status: .accepted,
                note: nil, declineReason: nil
            ),
            // Die Woche des Lokals — am Wochenbeginn verankert, damit sie an
            // jedem Wochentag etwas zeigt.
            KitchenLinkPlannedShift(
                id: "demo-plan-3", userID: "demo-2", email: "sarah@restaurant.de",
                roleName: "Schichtleitung", startsAt: inWeek(1, 16), endsAt: inWeek(1, 23),
                area: nil, station: nil, status: .accepted, note: nil, declineReason: nil
            ),
            KitchenLinkPlannedShift(
                id: "demo-plan-4", userID: "demo-4", email: "mira@restaurant.de",
                roleName: "Küche", startsAt: inWeek(1, 15), endsAt: inWeek(1, 22),
                area: nil, station: "kitchen", status: .published,
                note: nil, declineReason: nil
            ),
            // Zwei Entwürfe: sichtbar nur für die Planung.
            KitchenLinkPlannedShift(
                id: "demo-plan-5", userID: "demo-3", email: "jonas@restaurant.de",
                roleName: "Service", startsAt: inWeek(2, 17), endsAt: inWeek(2, 23),
                area: "Gastraum", station: nil, status: .draft, note: nil, declineReason: nil
            ),
            KitchenLinkPlannedShift(
                id: "demo-plan-6", userID: "demo-2", email: "sarah@restaurant.de",
                roleName: "Schichtleitung", startsAt: inWeek(4, 17), endsAt: inWeek(4, 23),
                area: nil, station: nil, status: .draft, note: nil, declineReason: nil
            )
        ]
    }

    private func fail(_ code: String) -> KitchenLinkCloudServiceError {
        KitchenLinkCloudServiceError.server(status: 400, message: code)
    }

    /// Dieselbe Regel wie der Ausschluss-Constraint: gleiche Person,
    /// überlappender Zeitraum, und die abgelehnte zählt nicht mit.
    private func overlaps(
        userID: String, from: Date, to: Date, ignoring shiftID: String?
    ) -> Bool {
        shifts.contains { existing in
            existing.userID == userID
                && existing.id != shiftID
                && existing.status != .declined
                && existing.startsAt < to
                && from < existing.endsAt
        }
    }

    func loadMyShifts(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        daysAhead: Int
    ) async throws -> [KitchenLinkPlannedShift] {
        let horizon = Date().addingTimeInterval(Double(daysAhead) * 86_400)
        return shifts
            .filter {
                $0.userID == meID && $0.status != .draft
                    && $0.endsAt >= Date() && $0.startsAt < horizon
            }
            .sorted { $0.startsAt < $1.startsAt }
    }

    func loadVenueSchedule(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        from: Date,
        to: Date
    ) async throws -> [KitchenLinkPlannedShift] {
        shifts
            .filter { $0.startsAt >= from && $0.startsAt < to }
            .sorted { ($0.startsAt, $0.email ?? "") < ($1.startsAt, $1.email ?? "") }
    }

    func planShift(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        userID: String,
        startsAt: Date,
        endsAt: Date,
        area: String?,
        station: String?,
        note: String?,
        shiftID: String?
    ) async throws {
        guard endsAt > startsAt else { throw fail("plan_invalid_range") }
        if let station, !["kitchen", "bar"].contains(station) {
            throw fail("plan_invalid_station")
        }
        guard !overlaps(userID: userID, from: startsAt, to: endsAt, ignoring: shiftID) else {
            throw fail("plan_overlaps")
        }

        if let shiftID {
            guard let index = shifts.firstIndex(where: { $0.id == shiftID }) else {
                throw fail("plan_unknown_shift")
            }
            let old = shifts[index]
            shifts[index] = KitchenLinkPlannedShift(
                id: old.id, userID: old.userID, email: old.email, roleName: old.roleName,
                startsAt: startsAt, endsAt: endsAt, area: area, station: station,
                // Verschieben hebt die Zusage auf — sonst stuende „angenommen"
                // an einer Zeit, die niemand gesehen hat.
                status: old.status == .accepted ? .published : old.status,
                note: note, declineReason: old.declineReason
            )
        } else {
            let existing = shifts.first { $0.userID == userID }
            shifts.append(
                KitchenLinkPlannedShift(
                    id: "demo-plan-\(shifts.count + 1)",
                    userID: userID, email: existing?.email, roleName: existing?.roleName,
                    startsAt: startsAt, endsAt: endsAt, area: area, station: station,
                    status: .draft, note: note, declineReason: nil
                )
            )
        }
    }

    func deleteShift(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        shiftID: String
    ) async throws {
        guard let index = shifts.firstIndex(where: { $0.id == shiftID }) else {
            throw fail("plan_unknown_shift")
        }
        shifts.remove(at: index)
    }

    func publish(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        from: Date,
        to: Date
    ) async throws -> Int {
        var count = 0
        for index in shifts.indices
        where shifts[index].status == .draft
            && shifts[index].startsAt >= from && shifts[index].startsAt < to {
            let old = shifts[index]
            shifts[index] = KitchenLinkPlannedShift(
                id: old.id, userID: old.userID, email: old.email, roleName: old.roleName,
                startsAt: old.startsAt, endsAt: old.endsAt, area: old.area,
                station: old.station, status: .published, note: old.note,
                declineReason: nil
            )
            count += 1
        }
        return count
    }

    func respond(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        shiftID: String,
        accept: Bool,
        reason: String?
    ) async throws {
        guard let index = shifts.firstIndex(where: { $0.id == shiftID }) else {
            throw fail("plan_unknown_shift")
        }
        guard shifts[index].userID == meID else { throw fail("plan_not_yours") }
        guard shifts[index].status == .published else { throw fail("plan_not_published") }

        let old = shifts[index]
        shifts[index] = KitchenLinkPlannedShift(
            id: old.id, userID: old.userID, email: old.email, roleName: old.roleName,
            startsAt: old.startsAt, endsAt: old.endsAt, area: old.area, station: old.station,
            status: accept ? .accepted : .declined, note: old.note,
            declineReason: accept ? nil : reason
        )
    }
}
