import Foundation

/// KL-STAFFING-001: Sandbox-Demo der Sollbesetzung ohne Cloud.
///
/// Er rechnet die Abdeckung **wie die Datenbank**: nur überlappende, nicht
/// abgelehnte Schichten zählen, eine Station filtert, und gezählt werden
/// Personen. Anders als dort geschieht das hier im Speicher — der Demo-Plan
/// wird ihm dafür beim Bauen mitgegeben.
///
/// **Es wird kein Bedarf gespeichert.**
actor KitchenLinkDemoStaffingTransport: KitchenLinkStaffingTransport {
    private var requirements: [KitchenLinkStaffingRequirement]
    private let shifts: KitchenLinkDemoScheduleTransport

    init(
        shifts: KitchenLinkDemoScheduleTransport = KitchenLinkDemoScheduleTransport(),
        seeded: Bool = true
    ) {
        self.shifts = shifts
        guard seeded else {
            requirements = []
            return
        }
        // Zwei Muster, die im Demo etwas zeigen: der Freitagabend ist knapp,
        // der Dienstagabend gedeckt.
        requirements = [
            KitchenLinkStaffingRequirement(
                id: "demo-req-1", weekday: 5,
                startsAtLocal: "17:00:00", endsAtLocal: "23:00:00",
                station: nil, area: "Gastraum", targetHeadcount: 3
            ),
            KitchenLinkStaffingRequirement(
                id: "demo-req-2", weekday: 2,
                startsAtLocal: "16:00:00", endsAtLocal: "23:00:00",
                station: nil, area: nil, targetHeadcount: 2
            )
        ]
    }

    private func fail(_ code: String) -> KitchenLinkCloudServiceError {
        KitchenLinkCloudServiceError.server(status: 400, message: code)
    }

    func loadRequirements(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> [KitchenLinkStaffingRequirement] {
        requirements.sorted {
            ($0.weekday, $0.startsAtLocal) < ($1.weekday, $1.startsAtLocal)
        }
    }

    func loadCoverage(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        from: Date,
        to: Date
    ) async throws -> [KitchenLinkStaffingCoverage] {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let planned = try await shifts.loadVenueSchedule(
            config: config, session: session, venueSlug: venueSlug,
            from: cal.startOfDay(for: from),
            to: cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: to)) ?? to
        )

        var result: [KitchenLinkStaffingCoverage] = []
        var day = cal.startOfDay(for: from)
        let last = cal.startOfDay(for: to)

        while day <= last {
            // `weekday` ist 1 = Sonntag im gregorianischen Kalender; die
            // Datenbank zählt nach ISO 8601 mit 1 = Montag.
            let isoWeekday = (cal.component(.weekday, from: day) + 5) % 7 + 1
            for requirement in requirements where requirement.weekday == isoWeekday {
                guard let start = time(requirement.startsAtLocal, on: day, calendar: cal),
                      let end = time(requirement.endsAtLocal, on: day, calendar: cal) else {
                    continue
                }
                let people = Set(
                    planned
                        .filter { shift in
                            shift.status != .declined
                                && (requirement.station == nil
                                    || shift.station == requirement.station)
                                && shift.startsAt < end && start < shift.endsAt
                        }
                        .compactMap(\.userID)
                )
                result.append(
                    KitchenLinkStaffingCoverage(
                        requirementID: requirement.id, day: day,
                        startsAt: start, endsAt: end,
                        station: requirement.station, area: requirement.area,
                        targetHeadcount: requirement.targetHeadcount,
                        plannedHeadcount: people.count,
                        missing: max(0, requirement.targetHeadcount - people.count)
                    )
                )
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    private func time(_ local: String, on day: Date, calendar: Calendar) -> Date? {
        let parts = local.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return calendar.date(
            bySettingHour: parts[0], minute: parts[1], second: 0, of: day
        )
    }

    func upsertRequirement(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        weekday: Int,
        startsAtLocal: String,
        endsAtLocal: String,
        targetHeadcount: Int,
        station: String?,
        area: String?
    ) async throws {
        guard (1...7).contains(weekday) else { throw fail("staffing_invalid_weekday") }
        guard startsAtLocal < endsAtLocal else { throw fail("staffing_invalid_window") }
        guard targetHeadcount >= 1 else { throw fail("staffing_invalid_headcount") }
        if let station, !["kitchen", "bar"].contains(station) {
            throw fail("staffing_invalid_station")
        }

        requirements.append(
            KitchenLinkStaffingRequirement(
                id: "demo-req-\(requirements.count + 1)", weekday: weekday,
                startsAtLocal: startsAtLocal, endsAtLocal: endsAtLocal,
                station: station, area: area, targetHeadcount: targetHeadcount
            )
        )
    }

    func deleteRequirement(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        requirementID: String
    ) async throws {
        guard let index = requirements.firstIndex(where: { $0.id == requirementID }) else {
            throw fail("staffing_unknown_requirement")
        }
        requirements.remove(at: index)
    }
}
