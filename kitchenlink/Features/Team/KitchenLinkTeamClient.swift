import Foundation

/// KL-ROLE-001: Rollen und Rechte gegen die Sandbox-Instanz.
///
/// Bis hierher galt: wer angemeldet ist, darf alles. Ab jetzt tragen die fünf
/// sensiblen Aktionen ein Recht. Die App fragt die eigenen Rechte **einmal**
/// und sperrt danach, was gesperrt gehört — statt den Nutzer in einen
/// Serverfehler laufen zu lassen. Die Sperre in der Oberfläche ist Höflichkeit,
/// die Durchsetzung steht in der Datenbank.

/// Die fünf Rechte, die es heute gibt. Bewusst kein Recht mehr: was hier steht,
/// wird auch geprüft (Migration `20260731220000_roles_and_permissions.sql`).
enum KitchenLinkVenuePermission: String, CaseIterable, Sendable {
    case shiftOpen = "shift.open"
    case shiftClose = "shift.close"
    case cashMovement = "cash.movement"
    case paymentsRefund = "payments.refund"
    case staffManage = "staff.manage"

    var label: String {
        switch self {
        case .shiftOpen: "Schicht öffnen"
        case .shiftClose: "Kasse abschließen"
        case .cashMovement: "Bargeld bewegen"
        case .paymentsRefund: "Zahlung stornieren"
        case .staffManage: "Personal verwalten"
        }
    }
}

/// Was der angemeldete Zugang in dieser Venue ist und darf.
struct KitchenLinkMyRole: Equatable, Sendable {
    let roleKey: String?
    let roleName: String?
    let permissions: Set<String>

    static let none = KitchenLinkMyRole(roleKey: nil, roleName: nil, permissions: [])

    /// Gehört dieser Zugang überhaupt zum Personal?
    var isStaff: Bool { roleKey != nil }

    func can(_ permission: KitchenLinkVenuePermission) -> Bool {
        permissions.contains(permission.rawValue)
    }

    static func decode(_ data: Data) throws -> KitchenLinkMyRole {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        let raw = root["permissions"] as? [String] ?? []
        return KitchenLinkMyRole(
            roleKey: root["role"] as? String,
            roleName: root["role_name"] as? String,
            permissions: Set(raw)
        )
    }
}

struct KitchenLinkVenueRole: Identifiable, Equatable, Sendable {
    let key: String
    let name: String
    let permissions: [String]
    let isBuiltin: Bool
    let sortOrder: Int

    var id: String { key }

    /// „Keine sensiblen Rechte" ist eine Aussage, kein Mangel: die Rolle darf
    /// alles Alltägliche, nur nichts aus der Kasse.
    var permissionSummary: String {
        guard !permissions.isEmpty else { return "Nur Alltag, nichts Sensibles" }
        return permissions
            .compactMap { KitchenLinkVenuePermission(rawValue: $0)?.label }
            .joined(separator: " · ")
    }

    static func decode(_ row: [String: Any]) -> KitchenLinkVenueRole? {
        guard let key = row["key"] as? String, let name = row["name"] as? String else {
            return nil
        }
        return KitchenLinkVenueRole(
            key: key,
            name: name,
            permissions: row["permissions"] as? [String] ?? [],
            isBuiltin: row["is_builtin"] as? Bool ?? false,
            sortOrder: row["sort_order"] as? Int ?? 0
        )
    }
}

struct KitchenLinkTeamMember: Identifiable, Equatable, Sendable {
    let userID: String
    let email: String?
    let roleKey: String
    let roleName: String
    let isMe: Bool

    var id: String { userID }

    /// Ohne lesbare E-Mail bleibt die Kennung — lieber eine unschöne Zeile als
    /// ein namenloser Eintrag, den niemand zuordnen kann.
    var displayName: String { email ?? String(userID.prefix(8)) }

    static func decode(_ row: [String: Any]) -> KitchenLinkTeamMember? {
        guard let userID = row["user_id"] as? String,
              let roleKey = row["role"] as? String,
              let roleName = row["role_name"] as? String else {
            return nil
        }
        return KitchenLinkTeamMember(
            userID: userID,
            email: row["email"] as? String,
            roleKey: roleKey,
            roleName: roleName,
            isMe: row["is_me"] as? Bool ?? false
        )
    }
}

protocol KitchenLinkPermissionTransport: Sendable {
    func loadMyRole(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> KitchenLinkMyRole
}

protocol KitchenLinkTeamTransport: KitchenLinkPermissionTransport {
    func loadTeam(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> [KitchenLinkTeamMember]

    func loadRoles(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> [KitchenLinkVenueRole]

    func addStaff(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        email: String,
        roleKey: String
    ) async throws

    func setStaffRole(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        userID: String,
        roleKey: String
    ) async throws

    func removeStaff(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        userID: String
    ) async throws
}

extension URLSessionKitchenLinkCloudTransport: KitchenLinkTeamTransport {
    func loadMyRole(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> KitchenLinkMyRole {
        struct Body: Encodable { let p_venue_slug: String }
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_my_permissions",
            bodyData: try JSONEncoder().encode(Body(p_venue_slug: venueSlug))
        )
        return try KitchenLinkMyRole.decode(data)
    }

    func loadTeam(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> [KitchenLinkTeamMember] {
        struct Body: Encodable { let p_venue_slug: String }
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_venue_team",
            bodyData: try JSONEncoder().encode(Body(p_venue_slug: venueSlug))
        )
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        return rows.compactMap(KitchenLinkTeamMember.decode)
    }

    func loadRoles(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> [KitchenLinkVenueRole] {
        struct Body: Encodable { let p_venue_slug: String }
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_venue_roles",
            bodyData: try JSONEncoder().encode(Body(p_venue_slug: venueSlug))
        )
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        return rows.compactMap(KitchenLinkVenueRole.decode).sorted { $0.sortOrder < $1.sortOrder }
    }

    func addStaff(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        email: String,
        roleKey: String
    ) async throws {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_email: String
            let p_role: String
        }
        _ = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_add_staff",
            bodyData: try JSONEncoder().encode(
                Body(p_venue_slug: venueSlug, p_email: email, p_role: roleKey)
            )
        )
    }

    func setStaffRole(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        userID: String,
        roleKey: String
    ) async throws {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_user_id: String
            let p_role: String
        }
        _ = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_set_staff_role",
            bodyData: try JSONEncoder().encode(
                Body(p_venue_slug: venueSlug, p_user_id: userID, p_role: roleKey)
            )
        )
    }

    func removeStaff(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        userID: String
    ) async throws {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_user_id: String
        }
        _ = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_remove_staff",
            bodyData: try JSONEncoder().encode(
                Body(p_venue_slug: venueSlug, p_user_id: userID)
            )
        )
    }
}
