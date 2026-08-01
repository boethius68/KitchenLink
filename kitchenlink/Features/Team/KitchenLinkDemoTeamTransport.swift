import Foundation

/// KL-ROLE-001: Sandbox-Demo der Personalverwaltung ohne Cloud.
///
/// Er verhält sich wie die Datenbank — die eigene Rolle ist unveränderlich, der
/// letzte Inhaber bleibt Inhaber, ein Manager kommt an einen Inhaber nicht
/// heran, und ohne Konto gibt es keine Zuordnung —, damit die Demo nichts
/// anderes zeigt als der echte Weg.
///
/// **Es wird niemand eingeladen und nichts geändert.**
actor KitchenLinkDemoTeamTransport: KitchenLinkTeamTransport {
    private static let builtinRoles: [KitchenLinkVenueRole] = [
        KitchenLinkVenueRole(
            key: "owner", name: "Inhaber",
            permissions: ["shift.open", "shift.close", "cash.movement",
                          "payments.refund", "staff.manage"],
            isBuiltin: true, sortOrder: 10
        ),
        KitchenLinkVenueRole(
            key: "manager", name: "Manager",
            permissions: ["shift.open", "shift.close", "cash.movement",
                          "payments.refund", "staff.manage"],
            isBuiltin: true, sortOrder: 20
        ),
        KitchenLinkVenueRole(
            key: "shift_lead", name: "Schichtleitung",
            permissions: ["shift.open", "shift.close", "cash.movement", "payments.refund"],
            isBuiltin: true, sortOrder: 30
        ),
        KitchenLinkVenueRole(key: "service", name: "Service", permissions: [],
                             isBuiltin: true, sortOrder: 40),
        KitchenLinkVenueRole(key: "kitchen", name: "Küche", permissions: [],
                             isBuiltin: true, sortOrder: 50),
        KitchenLinkVenueRole(key: "bar", name: "Bar", permissions: [],
                             isBuiltin: true, sortOrder: 60),
        KitchenLinkVenueRole(key: "driver", name: "Fahrer", permissions: [],
                             isBuiltin: true, sortOrder: 70),
        KitchenLinkVenueRole(key: "stock", name: "Lager", permissions: [],
                             isBuiltin: true, sortOrder: 80),
        KitchenLinkVenueRole(key: "accounting", name: "Buchhaltung", permissions: [],
                             isBuiltin: true, sortOrder: 90)
    ]

    private var members: [KitchenLinkTeamMember]
    private let knownAccounts: Set<String>
    private let meID = "demo-me"

    init(members: [KitchenLinkTeamMember]? = nil) {
        // KL-ROLE-002: der Demo-Zugang ist sonst Inhaber und darf alles — der
        // gesperrte Zustand wäre damit nicht vorführbar, und die Freigabe per
        // PIN erst recht nicht.
        let mine = KitchenLinkDesignPreviewConfiguration.shouldUseDemoServiceRole()
            ? ("service", "Service")
            : ("owner", "Inhaber")
        self.members = members ?? [
            KitchenLinkTeamMember(
                userID: "demo-me", email: "du@restaurant.de",
                roleKey: mine.0, roleName: mine.1, isMe: true
            ),
            KitchenLinkTeamMember(
                userID: "demo-2", email: "sarah@restaurant.de",
                roleKey: "shift_lead", roleName: "Schichtleitung", isMe: false
            ),
            KitchenLinkTeamMember(
                userID: "demo-3", email: "jonas@restaurant.de",
                roleKey: "service", roleName: "Service", isMe: false
            ),
            KitchenLinkTeamMember(
                userID: "demo-4", email: "mira@restaurant.de",
                roleKey: "kitchen", roleName: "Küche", isMe: false
            )
        ]
        self.knownAccounts = ["neu@restaurant.de", "aushilfe@restaurant.de"]
    }

    private func role(_ key: String) -> KitchenLinkVenueRole? {
        Self.builtinRoles.first { $0.key == key }
    }

    private func fail(_ code: String) -> KitchenLinkCloudServiceError {
        KitchenLinkCloudServiceError.server(status: 400, message: code)
    }

    func loadMyRole(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> KitchenLinkMyRole {
        guard let me = members.first(where: { $0.isMe }), let r = role(me.roleKey) else {
            return .none
        }
        return KitchenLinkMyRole(
            roleKey: r.key, roleName: r.name, permissions: Set(r.permissions)
        )
    }

    func loadTeam(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> [KitchenLinkTeamMember] {
        members.sorted {
            (role($0.roleKey)?.sortOrder ?? 0, $0.email ?? "")
                < (role($1.roleKey)?.sortOrder ?? 0, $1.email ?? "")
        }
    }

    func loadRoles(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> [KitchenLinkVenueRole] { Self.builtinRoles }

    func addStaff(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        email: String,
        roleKey: String
    ) async throws {
        let normalized = email.lowercased()
        guard let r = role(roleKey) else { throw fail("staff_unknown_role") }
        guard knownAccounts.contains(normalized) else { throw fail("staff_no_account") }
        guard !members.contains(where: { $0.email?.lowercased() == normalized }) else { return }

        members.append(
            KitchenLinkTeamMember(
                userID: "demo-\(members.count + 1)", email: normalized,
                roleKey: r.key, roleName: r.name, isMe: false
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
        guard userID != meID else { throw fail("staff_self_change") }
        guard let r = role(roleKey) else { throw fail("staff_unknown_role") }
        guard let index = members.firstIndex(where: { $0.userID == userID }) else {
            throw fail("staff_unknown")
        }
        if members[index].roleKey == "owner", roleKey != "owner",
           members.filter({ $0.roleKey == "owner" }).count <= 1 {
            throw fail("staff_last_owner")
        }
        let existing = members[index]
        members[index] = KitchenLinkTeamMember(
            userID: existing.userID, email: existing.email,
            roleKey: r.key, roleName: r.name, isMe: existing.isMe
        )
    }

    func removeStaff(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        userID: String
    ) async throws {
        guard userID != meID else { throw fail("staff_self_change") }
        guard let index = members.firstIndex(where: { $0.userID == userID }) else {
            throw fail("staff_unknown")
        }
        if members[index].roleKey == "owner",
           members.filter({ $0.roleKey == "owner" }).count <= 1 {
            throw fail("staff_last_owner")
        }
        members.remove(at: index)
    }
}
