import Foundation

/// KL-TIME-001: Zeiterfassung gegen die Sandbox-Instanz (Blueprint §9.3).
///
/// Alle Wege laufen über die RPCs aus Migration `20260801120000_time_clock.sql`.
/// **Die Dauer wird nie vom Gerät bestimmt**: der Server kennt Beginn, Pausen
/// und Ende, und nur er kann sie über mehrere Geräte hinweg zusammenrechnen.
/// Die App zeigt die laufende Zeit lokal weiter, damit die Anzeige nicht
/// stockt — gebucht wird immer der Serverwert.

struct KitchenLinkTimeTotals: Equatable, Sendable {
    let grossSeconds: Int
    let breakSeconds: Int
    let netSeconds: Int

    static let zero = KitchenLinkTimeTotals(grossSeconds: 0, breakSeconds: 0, netSeconds: 0)

    static func decode(_ raw: [String: Any]?) -> KitchenLinkTimeTotals {
        guard let raw else { return .zero }
        return KitchenLinkTimeTotals(
            grossSeconds: raw["gross_seconds"] as? Int ?? 0,
            breakSeconds: raw["break_seconds"] as? Int ?? 0,
            netSeconds: raw["net_seconds"] as? Int ?? 0
        )
    }
}

struct KitchenLinkTimeEntry: Identifiable, Equatable, Sendable {
    let id: String
    let startedAt: Date?
    let endedAt: Date?
    let status: String
    let corrected: Bool
    let totals: KitchenLinkTimeTotals

    var isOpen: Bool { status == "open" }

    static func decode(_ row: [String: Any]) -> KitchenLinkTimeEntry? {
        guard let id = row["id"] as? String else { return nil }
        return KitchenLinkTimeEntry(
            id: id,
            startedAt: (row["started_at"] as? String).flatMap(KitchenLinkCloudTimestamp.parse),
            endedAt: (row["ended_at"] as? String).flatMap(KitchenLinkCloudTimestamp.parse),
            status: row["status"] as? String ?? "closed",
            corrected: row["corrected"] as? Bool ?? false,
            totals: KitchenLinkTimeTotals.decode(row["totals"] as? [String: Any])
        )
    }
}

/// Eintrag eines anderen Menschen, wie ihn eine Führungskraft sieht.
struct KitchenLinkTeamTimeEntry: Identifiable, Equatable, Sendable {
    let id: String
    let userID: String
    let email: String?
    let roleName: String?
    let startedAt: Date?
    let endedAt: Date?
    let status: String
    let onBreak: Bool
    let corrected: Bool
    let correctionReason: String?
    let totals: KitchenLinkTimeTotals

    var isOpen: Bool { status == "open" }
    var displayName: String { email ?? String(userID.prefix(8)) }

    static func decode(_ row: [String: Any]) -> KitchenLinkTeamTimeEntry? {
        guard let id = row["id"] as? String, let userID = row["user_id"] as? String else {
            return nil
        }
        return KitchenLinkTeamTimeEntry(
            id: id,
            userID: userID,
            email: row["email"] as? String,
            roleName: row["role_name"] as? String,
            startedAt: (row["started_at"] as? String).flatMap(KitchenLinkCloudTimestamp.parse),
            endedAt: (row["ended_at"] as? String).flatMap(KitchenLinkCloudTimestamp.parse),
            status: row["status"] as? String ?? "closed",
            onBreak: row["on_break"] as? Bool ?? false,
            corrected: row["corrected"] as? Bool ?? false,
            correctionReason: row["correction_reason"] as? String,
            totals: KitchenLinkTimeTotals.decode(row["totals"] as? [String: Any])
        )
    }
}

struct KitchenLinkTimeStatus: Equatable, Sendable {
    let clockedIn: Bool
    let entryID: String?
    let startedAt: Date?
    let onBreak: Bool
    let breakStartedAt: Date?
    let current: KitchenLinkTimeTotals?
    let todayNetSeconds: Int
    let today: [KitchenLinkTimeEntry]

    static let none = KitchenLinkTimeStatus(
        clockedIn: false, entryID: nil, startedAt: nil, onBreak: false,
        breakStartedAt: nil, current: nil, todayNetSeconds: 0, today: []
    )

    static func decode(_ data: Data) throws -> KitchenLinkTimeStatus {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        let rows = root["today"] as? [[String: Any]] ?? []
        return KitchenLinkTimeStatus(
            clockedIn: root["clocked_in"] as? Bool ?? false,
            entryID: root["entry_id"] as? String,
            startedAt: (root["started_at"] as? String).flatMap(KitchenLinkCloudTimestamp.parse),
            onBreak: root["on_break"] as? Bool ?? false,
            breakStartedAt: (root["break_started_at"] as? String)
                .flatMap(KitchenLinkCloudTimestamp.parse),
            current: (root["current"] as? [String: Any]).map(KitchenLinkTimeTotals.decode),
            todayNetSeconds: root["today_net_seconds"] as? Int ?? 0,
            today: rows.compactMap(KitchenLinkTimeEntry.decode)
        )
    }
}

enum KitchenLinkBreakKind: String, CaseIterable, Sendable {
    case restBreak = "rest_break"
    case mealBreak = "meal_break"

    var label: String {
        switch self {
        case .restBreak: "Pause"
        case .mealBreak: "Essenspause"
        }
    }
}

/// Sekunden als „2:05 h" bzw. „14 min" — im Betrieb liest niemand 7523.
enum KitchenLinkDurationText {
    static func hoursMinutes(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        guard hours > 0 else { return "\(minutes) min" }
        return "\(hours):" + String(format: "%02d", minutes) + " h"
    }

    /// Mit Sekunden, für eine laufende Uhr.
    static func running(_ seconds: Int) -> String {
        let total = max(0, seconds)
        return "\(total / 3600):"
            + String(format: "%02d", (total % 3600) / 60) + ":"
            + String(format: "%02d", total % 60)
    }
}

protocol KitchenLinkTimeClockTransport: Sendable {
    func loadStatus(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> KitchenLinkTimeStatus

    func clockIn(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws

    func clockOut(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws

    func startBreak(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        kind: KitchenLinkBreakKind
    ) async throws

    func endBreak(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws

    func loadTeam(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        daysBack: Int
    ) async throws -> [KitchenLinkTeamTimeEntry]

    func correct(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        entryID: String,
        reason: String,
        endedAt: Date
    ) async throws
}

extension URLSessionKitchenLinkCloudTransport: KitchenLinkTimeClockTransport {
    private struct VenueBody: Encodable { let p_venue_slug: String }

    func loadStatus(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> KitchenLinkTimeStatus {
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_my_time_status",
            bodyData: try JSONEncoder().encode(VenueBody(p_venue_slug: venueSlug))
        )
        return try KitchenLinkTimeStatus.decode(data)
    }

    func clockIn(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws {
        _ = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_clock_in",
            bodyData: try JSONEncoder().encode(VenueBody(p_venue_slug: venueSlug))
        )
    }

    func clockOut(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws {
        _ = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_clock_out",
            bodyData: try JSONEncoder().encode(VenueBody(p_venue_slug: venueSlug))
        )
    }

    func startBreak(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        kind: KitchenLinkBreakKind
    ) async throws {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_kind: String
        }
        _ = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_break_start",
            bodyData: try JSONEncoder().encode(
                Body(p_venue_slug: venueSlug, p_kind: kind.rawValue)
            )
        )
    }

    func endBreak(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws {
        _ = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_break_end",
            bodyData: try JSONEncoder().encode(VenueBody(p_venue_slug: venueSlug))
        )
    }

    func loadTeam(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        daysBack: Int
    ) async throws -> [KitchenLinkTeamTimeEntry] {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_days_back: Int
        }
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_team_time",
            bodyData: try JSONEncoder().encode(
                Body(p_venue_slug: venueSlug, p_days_back: daysBack)
            )
        )
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        return rows.compactMap(KitchenLinkTeamTimeEntry.decode)
    }

    func correct(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        entryID: String,
        reason: String,
        endedAt: Date
    ) async throws {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_entry_id: String
            let p_reason: String
            let p_ended_at: String
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        _ = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_correct_time_entry",
            bodyData: try JSONEncoder().encode(
                Body(
                    p_venue_slug: venueSlug,
                    p_entry_id: entryID,
                    p_reason: reason,
                    p_ended_at: formatter.string(from: endedAt)
                )
            )
        )
    }
}
