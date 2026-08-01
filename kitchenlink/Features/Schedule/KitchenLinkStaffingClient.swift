import Foundation

/// KL-STAFFING-001: Sollbesetzung gegen die Sandbox-Instanz (Blueprint §9.2).
///
/// Der Dienstplan zeigt, **wer** eingeteilt ist. Diese Schicht beantwortet die
/// Frage, die eine Planende beim Blick auf die Woche wirklich hat: **reicht
/// das?**
///
/// Gerechnet wird die Abdeckung **in der Datenbank** — nur sie kennt den Plan,
/// den alle Geräte teilen, und nur sie löst das Zeitfenster korrekt in der
/// Zeitzone der Venue auf, Sommerzeit eingeschlossen.

struct KitchenLinkStaffingRequirement: Identifiable, Equatable, Sendable {
    let id: String
    /// 1 = Montag … 7 = Sonntag (ISO 8601).
    let weekday: Int
    let startsAtLocal: String
    let endsAtLocal: String
    let station: String?
    let area: String?
    let targetHeadcount: Int

    static let weekdayNames = [
        1: "Montag", 2: "Dienstag", 3: "Mittwoch", 4: "Donnerstag",
        5: "Freitag", 6: "Samstag", 7: "Sonntag"
    ]

    var weekdayName: String { Self.weekdayNames[weekday] ?? "—" }

    /// „17:00–23:00" — die Datenbank liefert `HH:MM:SS`.
    var windowLabel: String {
        "\(String(startsAtLocal.prefix(5)))–\(String(endsAtLocal.prefix(5)))"
    }

    var stationLabel: String? {
        station.flatMap { KitchenLinkShiftStation(rawValue: $0)?.label }
    }

    static func decode(_ row: [String: Any]) -> KitchenLinkStaffingRequirement? {
        guard let id = row["id"] as? String,
              let weekday = row["weekday"] as? Int,
              let starts = row["starts_at_local"] as? String,
              let ends = row["ends_at_local"] as? String,
              let target = row["target_headcount"] as? Int else {
            return nil
        }
        return KitchenLinkStaffingRequirement(
            id: id, weekday: weekday, startsAtLocal: starts, endsAtLocal: ends,
            station: row["station"] as? String, area: row["area"] as? String,
            targetHeadcount: target
        )
    }
}

/// Ein Bedarf an einem konkreten Tag, mit dem Stand des Plans.
struct KitchenLinkStaffingCoverage: Identifiable, Equatable, Sendable {
    let requirementID: String
    let day: Date
    let startsAt: Date
    let endsAt: Date
    let station: String?
    let area: String?
    let targetHeadcount: Int
    let plannedHeadcount: Int
    let missing: Int

    var id: String { "\(requirementID)-\(day.timeIntervalSince1970)" }

    var isShort: Bool { missing > 0 }

    var stationLabel: String? {
        station.flatMap { KitchenLinkShiftStation(rawValue: $0)?.label }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func decode(_ row: [String: Any]) -> KitchenLinkStaffingCoverage? {
        guard let requirementID = row["requirement_id"] as? String,
              let dayRaw = row["day"] as? String,
              let day = dayFormatter.date(from: dayRaw),
              let startsRaw = row["starts_at"] as? String,
              let endsRaw = row["ends_at"] as? String,
              let starts = KitchenLinkCloudTimestamp.parse(startsRaw),
              let ends = KitchenLinkCloudTimestamp.parse(endsRaw),
              let target = row["target_headcount"] as? Int,
              let planned = row["planned_headcount"] as? Int,
              let missing = row["missing"] as? Int else {
            return nil
        }
        return KitchenLinkStaffingCoverage(
            requirementID: requirementID, day: day, startsAt: starts, endsAt: ends,
            station: row["station"] as? String, area: row["area"] as? String,
            targetHeadcount: target, plannedHeadcount: planned, missing: missing
        )
    }
}

protocol KitchenLinkStaffingTransport: Sendable {
    func loadRequirements(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> [KitchenLinkStaffingRequirement]

    func loadCoverage(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        from: Date,
        to: Date
    ) async throws -> [KitchenLinkStaffingCoverage]

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
    ) async throws

    func deleteRequirement(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        requirementID: String
    ) async throws
}

extension URLSessionKitchenLinkCloudTransport: KitchenLinkStaffingTransport {
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    func loadRequirements(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> [KitchenLinkStaffingRequirement] {
        struct Body: Encodable { let p_venue_slug: String }
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_staffing_requirements",
            bodyData: try JSONEncoder().encode(Body(p_venue_slug: venueSlug))
        )
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        return rows.compactMap(KitchenLinkStaffingRequirement.decode)
    }

    func loadCoverage(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        from: Date,
        to: Date
    ) async throws -> [KitchenLinkStaffingCoverage] {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_from: String
            let p_to: String
        }
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_staffing_coverage",
            bodyData: try JSONEncoder().encode(
                Body(
                    p_venue_slug: venueSlug,
                    p_from: Self.dayFormatter.string(from: from),
                    p_to: Self.dayFormatter.string(from: to)
                )
            )
        )
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        return rows.compactMap(KitchenLinkStaffingCoverage.decode)
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
        struct Body: Encodable {
            let p_venue_slug: String
            let p_weekday: Int
            let p_starts_at_local: String
            let p_ends_at_local: String
            let p_target_headcount: Int
            let p_station: String?
            let p_area: String?
        }
        _ = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_upsert_staffing_requirement",
            bodyData: try JSONEncoder().encode(
                Body(
                    p_venue_slug: venueSlug, p_weekday: weekday,
                    p_starts_at_local: startsAtLocal, p_ends_at_local: endsAtLocal,
                    p_target_headcount: targetHeadcount,
                    p_station: station, p_area: area
                )
            )
        )
    }

    func deleteRequirement(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        requirementID: String
    ) async throws {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_requirement_id: String
        }
        _ = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_delete_staffing_requirement",
            bodyData: try JSONEncoder().encode(
                Body(p_venue_slug: venueSlug, p_requirement_id: requirementID)
            )
        )
    }
}
