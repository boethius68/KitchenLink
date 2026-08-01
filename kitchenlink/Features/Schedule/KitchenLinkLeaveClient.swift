import Foundation

/// KL-LEAVE-001: Abwesenheiten gegen die Sandbox-Instanz (Blueprint §9.2).
///
/// Die tragende Regel ist eine **Asymmetrie**, und sie steht in der Datenbank:
/// in eine genehmigte Abwesenheit hinein wird nicht geplant — aber eine
/// Abwesenheit auf bereits geplante Schichten wird trotzdem genehmigt und
/// meldet sie nur. Eine Krankmeldung kommt nun einmal nach dem Dienstplan.

enum KitchenLinkLeaveKind: String, CaseIterable, Sendable {
    case vacation
    case sick
    case unpaid
    case training
    case other

    var label: String {
        switch self {
        case .vacation: "Urlaub"
        case .sick: "Krank"
        case .unpaid: "Unbezahlt"
        case .training: "Schulung"
        case .other: "Sonstiges"
        }
    }
}

enum KitchenLinkLeaveStatus: String, Sendable {
    case requested
    case approved
    case rejected
    case cancelled

    var label: String {
        switch self {
        case .requested: "Beantragt"
        case .approved: "Genehmigt"
        case .rejected: "Abgelehnt"
        case .cancelled: "Zurückgezogen"
        }
    }

    var isOpen: Bool { self == .requested }
}

struct KitchenLinkLeave: Identifiable, Equatable, Sendable {
    let id: String
    let userID: String?
    let email: String?
    let roleName: String?
    let startsAt: Date
    let endsAt: Date
    let kind: KitchenLinkLeaveKind
    let status: KitchenLinkLeaveStatus
    let reason: String?
    let reviewNote: String?
    /// Wie viele geplante Schichten dieser Zeitraum trifft. Bei einem offenen
    /// Antrag ist das die Zahl, die den Ausschlag gibt.
    let conflictingShifts: Int

    var displayName: String { email ?? userID.map { String($0.prefix(8)) } ?? "—" }

    /// Ganze Tage, weil eine Abwesenheit im Betrieb in Tagen gedacht wird.
    var dayCount: Int {
        max(1, Int((endsAt.timeIntervalSince(startsAt) / 86_400).rounded(.up)))
    }

    static func decode(_ row: [String: Any]) -> KitchenLinkLeave? {
        guard let id = row["id"] as? String,
              let startsRaw = row["starts_at"] as? String,
              let endsRaw = row["ends_at"] as? String,
              let starts = KitchenLinkCloudTimestamp.parse(startsRaw),
              let ends = KitchenLinkCloudTimestamp.parse(endsRaw),
              let kind = (row["kind"] as? String).flatMap(KitchenLinkLeaveKind.init(rawValue:)),
              let status = (row["status"] as? String)
                .flatMap(KitchenLinkLeaveStatus.init(rawValue:)) else {
            return nil
        }
        return KitchenLinkLeave(
            id: id,
            userID: row["user_id"] as? String,
            email: row["email"] as? String,
            roleName: row["role_name"] as? String,
            startsAt: starts,
            endsAt: ends,
            kind: kind,
            status: status,
            reason: row["reason"] as? String,
            reviewNote: row["review_note"] as? String,
            conflictingShifts: row["conflicting_shifts"] as? Int ?? 0
        )
    }
}

/// Was beim Genehmigen zurückkommt: die Schichten, die jetzt neu besetzt werden
/// müssen. Sie werden **nicht** automatisch gestrichen — das entscheidet die
/// Planung.
struct KitchenLinkLeaveDecision: Equatable, Sendable {
    let status: KitchenLinkLeaveStatus
    let conflictingShiftCount: Int
}

protocol KitchenLinkLeaveTransport: Sendable {
    func loadMyLeaves(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> [KitchenLinkLeave]

    func loadVenueLeaves(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        onlyOpen: Bool
    ) async throws -> [KitchenLinkLeave]

    func requestLeave(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        startsAt: Date,
        endsAt: Date,
        kind: KitchenLinkLeaveKind,
        reason: String?
    ) async throws

    func cancelLeave(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        leaveID: String
    ) async throws

    func reviewLeave(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        leaveID: String,
        approve: Bool,
        note: String?
    ) async throws -> KitchenLinkLeaveDecision
}

extension URLSessionKitchenLinkCloudTransport: KitchenLinkLeaveTransport {
    private func leaves(from data: Data) throws -> [KitchenLinkLeave] {
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        return rows.compactMap(KitchenLinkLeave.decode)
    }

    func loadMyLeaves(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> [KitchenLinkLeave] {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_days_back: Int
        }
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_my_leaves",
            bodyData: try JSONEncoder().encode(Body(p_venue_slug: venueSlug, p_days_back: 30))
        )
        return try leaves(from: data)
    }

    func loadVenueLeaves(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        onlyOpen: Bool
    ) async throws -> [KitchenLinkLeave] {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_only_open: Bool
        }
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_venue_leaves",
            bodyData: try JSONEncoder().encode(
                Body(p_venue_slug: venueSlug, p_only_open: onlyOpen)
            )
        )
        return try leaves(from: data)
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
        struct Body: Encodable {
            let p_venue_slug: String
            let p_starts_at: String
            let p_ends_at: String
            let p_kind: String
            let p_reason: String?
        }
        _ = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_request_leave",
            bodyData: try JSONEncoder().encode(
                Body(
                    p_venue_slug: venueSlug,
                    p_starts_at: KitchenLinkISOTimestamp.string(startsAt),
                    p_ends_at: KitchenLinkISOTimestamp.string(endsAt),
                    p_kind: kind.rawValue,
                    p_reason: reason
                )
            )
        )
    }

    func cancelLeave(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        leaveID: String
    ) async throws {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_leave_id: String
        }
        _ = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_cancel_leave",
            bodyData: try JSONEncoder().encode(
                Body(p_venue_slug: venueSlug, p_leave_id: leaveID)
            )
        )
    }

    func reviewLeave(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        leaveID: String,
        approve: Bool,
        note: String?
    ) async throws -> KitchenLinkLeaveDecision {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_leave_id: String
            let p_approve: Bool
            let p_note: String?
        }
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_review_leave",
            bodyData: try JSONEncoder().encode(
                Body(
                    p_venue_slug: venueSlug, p_leave_id: leaveID,
                    p_approve: approve, p_note: note
                )
            )
        )
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        let conflicts = root["conflicting_shifts"] as? [[String: Any]] ?? []
        return KitchenLinkLeaveDecision(
            status: (root["status"] as? String)
                .flatMap(KitchenLinkLeaveStatus.init(rawValue:)) ?? .requested,
            conflictingShiftCount: conflicts.count
        )
    }
}
