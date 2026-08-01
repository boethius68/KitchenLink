import Foundation

/// KL-PLAN-001: Dienstplan gegen die Sandbox-Instanz (Blueprint §9.2).
///
/// Alle Wege laufen über die RPCs aus Migration
/// `20260801140000_shift_schedule.sql`. Der Lebenszyklus ist derselbe wie in
/// der seit KL-WORKFORCE-001 getesteten Domäne
/// (`WorkforceShiftLifecycle.swift`): Entwurf → veröffentlicht → angenommen
/// oder abgelehnt. Die App erfindet daneben keinen zweiten.

enum KitchenLinkShiftPlanStatus: String, Sendable, CaseIterable {
    case draft
    case published
    case accepted
    case declined

    var label: String {
        switch self {
        case .draft: "Entwurf"
        case .published: "Veröffentlicht"
        case .accepted: "Angenommen"
        case .declined: "Abgelehnt"
        }
    }

    /// Nur eine veröffentlichte Schicht wartet auf eine Antwort.
    var awaitsResponse: Bool { self == .published }
}

enum KitchenLinkShiftStation: String, Sendable, CaseIterable {
    case kitchen
    case bar

    var label: String {
        switch self {
        case .kitchen: "Küche"
        case .bar: "Bar"
        }
    }
}

struct KitchenLinkPlannedShift: Identifiable, Equatable, Sendable {
    let id: String
    let userID: String?
    let email: String?
    let roleName: String?
    let startsAt: Date
    let endsAt: Date
    let area: String?
    let station: String?
    let status: KitchenLinkShiftPlanStatus
    let note: String?
    let declineReason: String?

    var displayName: String { email ?? userID.map { String($0.prefix(8)) } ?? "—" }

    /// „Gastraum · Küche" — nur was gesetzt ist, ohne leere Trenner.
    var placeLine: String? {
        let parts = [area, station.flatMap { KitchenLinkShiftStation(rawValue: $0)?.label }]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var durationSeconds: Int { max(0, Int(endsAt.timeIntervalSince(startsAt))) }

    static func decode(_ row: [String: Any]) -> KitchenLinkPlannedShift? {
        guard let id = row["id"] as? String,
              let startsRaw = row["starts_at"] as? String,
              let endsRaw = row["ends_at"] as? String,
              let starts = KitchenLinkCloudTimestamp.parse(startsRaw),
              let ends = KitchenLinkCloudTimestamp.parse(endsRaw) else {
            return nil
        }
        return KitchenLinkPlannedShift(
            id: id,
            userID: row["user_id"] as? String,
            email: row["email"] as? String,
            roleName: row["role_name"] as? String,
            startsAt: starts,
            endsAt: ends,
            area: row["area"] as? String,
            station: row["station"] as? String,
            status: (row["status"] as? String)
                .flatMap(KitchenLinkShiftPlanStatus.init(rawValue:)) ?? .draft,
            note: row["note"] as? String,
            declineReason: row["decline_reason"] as? String
        )
    }
}

protocol KitchenLinkScheduleTransport: Sendable {
    func loadMyShifts(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        daysAhead: Int
    ) async throws -> [KitchenLinkPlannedShift]

    func loadVenueSchedule(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        from: Date,
        to: Date
    ) async throws -> [KitchenLinkPlannedShift]

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
    ) async throws

    func deleteShift(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        shiftID: String
    ) async throws

    func publish(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        from: Date,
        to: Date
    ) async throws -> Int

    func respond(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        shiftID: String,
        accept: Bool,
        reason: String?
    ) async throws
}

/// PostgREST erwartet `timestamptz` als ISO-8601 mit Zonenangabe.
enum KitchenLinkISOTimestamp {
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func string(_ date: Date) -> String { formatter.string(from: date) }
}

extension URLSessionKitchenLinkCloudTransport: KitchenLinkScheduleTransport {
    private func shifts(from data: Data) throws -> [KitchenLinkPlannedShift] {
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        return rows.compactMap(KitchenLinkPlannedShift.decode)
    }

    func loadMyShifts(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        daysAhead: Int
    ) async throws -> [KitchenLinkPlannedShift] {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_days_ahead: Int
        }
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_my_shifts",
            bodyData: try JSONEncoder().encode(
                Body(p_venue_slug: venueSlug, p_days_ahead: daysAhead)
            )
        )
        return try shifts(from: data)
    }

    func loadVenueSchedule(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        from: Date,
        to: Date
    ) async throws -> [KitchenLinkPlannedShift] {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_from: String
            let p_to: String
        }
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_venue_schedule",
            bodyData: try JSONEncoder().encode(
                Body(
                    p_venue_slug: venueSlug,
                    p_from: KitchenLinkISOTimestamp.string(from),
                    p_to: KitchenLinkISOTimestamp.string(to)
                )
            )
        )
        return try shifts(from: data)
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
        struct Body: Encodable {
            let p_venue_slug: String
            let p_user_id: String
            let p_starts_at: String
            let p_ends_at: String
            let p_area: String?
            let p_station: String?
            let p_note: String?
            let p_shift_id: String?
        }
        _ = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_plan_shift",
            bodyData: try JSONEncoder().encode(
                Body(
                    p_venue_slug: venueSlug,
                    p_user_id: userID,
                    p_starts_at: KitchenLinkISOTimestamp.string(startsAt),
                    p_ends_at: KitchenLinkISOTimestamp.string(endsAt),
                    p_area: area,
                    p_station: station,
                    p_note: note,
                    p_shift_id: shiftID
                )
            )
        )
    }

    func deleteShift(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        shiftID: String
    ) async throws {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_shift_id: String
        }
        _ = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_delete_planned_shift",
            bodyData: try JSONEncoder().encode(
                Body(p_venue_slug: venueSlug, p_shift_id: shiftID)
            )
        )
    }

    func publish(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        from: Date,
        to: Date
    ) async throws -> Int {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_from: String
            let p_to: String
        }
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_publish_schedule",
            bodyData: try JSONEncoder().encode(
                Body(
                    p_venue_slug: venueSlug,
                    p_from: KitchenLinkISOTimestamp.string(from),
                    p_to: KitchenLinkISOTimestamp.string(to)
                )
            )
        )
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        return root["published"] as? Int ?? 0
    }

    func respond(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        shiftID: String,
        accept: Bool,
        reason: String?
    ) async throws {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_shift_id: String
            let p_accept: Bool
            let p_reason: String?
        }
        _ = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_respond_to_shift",
            bodyData: try JSONEncoder().encode(
                Body(
                    p_venue_slug: venueSlug,
                    p_shift_id: shiftID,
                    p_accept: accept,
                    p_reason: reason
                )
            )
        )
    }
}
