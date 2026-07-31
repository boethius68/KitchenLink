import Foundation

/// KL-ROLE-001: Zustand der Personalverwaltung.
///
/// Der Bildschirm selbst ist rechtepflichtig (`staff.manage`). Wer ihn nicht
/// öffnen darf, bekommt eine ruhige Ansage statt eines Serverfehlers — die
/// Datenbank würde den Zugriff ohnehin abweisen, aber ein Nutzer soll nicht
/// erst gegen eine Wand laufen, um das zu erfahren.
@MainActor
final class KitchenLinkTeamModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case ready
        case working
        case needsSignIn
        case notAllowed(String)
        case failed(String)
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var members: [KitchenLinkTeamMember] = []
    @Published private(set) var roles: [KitchenLinkVenueRole] = []
    @Published private(set) var myRole: KitchenLinkMyRole = .none
    @Published var notice: String?

    @Published var inviteEmail: String = ""
    @Published var inviteRoleKey: String = "service"

    private let config: KitchenLinkCloudConfig
    private let auth: KitchenLinkCloudAuthenticating
    private let transport: KitchenLinkTeamTransport
    private let store: KitchenLinkCloudCredentialStore
    private let requiresSession: Bool

    init(
        config: KitchenLinkCloudConfig = .sandboxDefault,
        auth: KitchenLinkCloudAuthenticating = URLSessionKitchenLinkCloudTransport(),
        transport: KitchenLinkTeamTransport = URLSessionKitchenLinkCloudTransport(),
        store: KitchenLinkCloudCredentialStore = KitchenLinkCloudCredentialStore(),
        requiresSession: Bool = true
    ) {
        self.config = config
        self.auth = auth
        self.transport = transport
        self.store = store
        self.requiresSession = requiresSession
    }

    static func make() -> KitchenLinkTeamModel {
        guard KitchenLinkDesignPreviewConfiguration.shouldSeedDemoTables() else {
            return KitchenLinkTeamModel()
        }
        return KitchenLinkTeamModel(
            transport: KitchenLinkDemoTeamTransport(),
            requiresSession: false
        )
    }

    private var currentSession: KitchenLinkCloudSession? {
        if let session = store.loadSession() { return session }
        guard !requiresSession else { return nil }
        return KitchenLinkCloudSession(
            accessToken: "", refreshToken: "", userID: "demo", expiresAt: .distantFuture
        )
    }

    var canManage: Bool { myRole.can(.staffManage) }

    var canInvite: Bool {
        phase != .working && canManage
            && inviteEmail.contains("@") && !inviteRoleKey.isEmpty
    }

    func role(for key: String) -> KitchenLinkVenueRole? {
        roles.first { $0.key == key }
    }

    // MARK: - Laden

    func load() async {
        guard let session = currentSession else {
            phase = .needsSignIn
            return
        }
        if phase != .working { phase = .loading }
        do {
            myRole = try await transport.loadMyRole(
                config: config, session: session, venueSlug: config.venueSlug
            )
            roles = try await transport.loadRoles(
                config: config, session: session, venueSlug: config.venueSlug
            )

            guard myRole.can(.staffManage) else {
                members = []
                phase = .notAllowed(
                    myRole.isStaff
                        ? "Als \(myRole.roleName ?? "Personal") kannst du das Team sehen, "
                            + "aber nicht ändern. Dafür braucht es Inhaber oder Manager."
                        : "Dieser Zugang gehört nicht zum Personal dieses Restaurants."
                )
                return
            }

            members = try await transport.loadTeam(
                config: config, session: session, venueSlug: config.venueSlug
            )
            phase = .ready
        } catch KitchenLinkCloudServiceError.unauthorized {
            store.clearSession()
            phase = .needsSignIn
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    func signIn(email: String, password: String) async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !password.isEmpty else {
            phase = .failed("E-Mail und Passwort sind erforderlich.")
            return
        }
        phase = .working
        do {
            let session = try await auth.signIn(config: config, email: trimmed, password: password)
            store.save(session: session)
            await load()
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    // MARK: - Ändern

    func invite() async {
        guard let session = currentSession else {
            phase = .needsSignIn
            return
        }
        let email = inviteEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard email.contains("@") else {
            notice = "Bitte eine E-Mail-Adresse eingeben."
            return
        }

        phase = .working
        do {
            try await transport.addStaff(
                config: config, session: session, venueSlug: config.venueSlug,
                email: email, roleKey: inviteRoleKey
            )
            notice = "\(email) gehört jetzt zum Team."
            inviteEmail = ""
            await load()
        } catch {
            // Der häufigste Fall verdient eine eigene Erklärung: KitchenLink
            // legt keine fremden Konten an.
            let message = Self.message(for: error)
            notice = message.contains("staff_no_account")
                ? "Zu \(email) gibt es noch kein Konto. Die Person muss sich zuerst "
                    + "selbst registrieren, danach kannst du sie zuordnen."
                : message
            phase = .ready
        }
    }

    func setRole(for member: KitchenLinkTeamMember, to roleKey: String) async {
        guard let session = currentSession else {
            phase = .needsSignIn
            return
        }
        guard roleKey != member.roleKey else { return }

        phase = .working
        do {
            try await transport.setStaffRole(
                config: config, session: session, venueSlug: config.venueSlug,
                userID: member.userID, roleKey: roleKey
            )
            notice = "\(member.displayName) ist jetzt "
                + "\(role(for: roleKey)?.name ?? roleKey)."
            await load()
        } catch {
            notice = Self.explain(Self.message(for: error))
            phase = .ready
        }
    }

    func remove(_ member: KitchenLinkTeamMember) async {
        guard let session = currentSession else {
            phase = .needsSignIn
            return
        }
        phase = .working
        do {
            try await transport.removeStaff(
                config: config, session: session, venueSlug: config.venueSlug,
                userID: member.userID
            )
            notice = "\(member.displayName) gehört nicht mehr zum Team."
            await load()
        } catch {
            notice = Self.explain(Self.message(for: error))
            phase = .ready
        }
    }

    /// Die Sperren der Datenbank in einem Satz, der im Betrieb weiterhilft.
    /// `nonisolated`, weil hier nur ein String umgeschrieben wird.
    nonisolated static func explain(_ message: String) -> String {
        if message.contains("staff_self_change") {
            return "Die eigene Rolle lässt sich nicht ändern — sonst könnte man "
                + "sich selbst aussperren."
        }
        if message.contains("staff_last_owner") {
            return "Das Restaurant braucht mindestens einen Inhaber."
        }
        if message.contains("staff_owner_protected") {
            return "Nur ein Inhaber kann einen anderen Inhaber ändern."
        }
        if message.contains("permission_denied") {
            return "Dafür fehlt diesem Zugang das Recht."
        }
        return message
    }

    private static func message(for error: Error) -> String {
        if let serviceError = error as? KitchenLinkCloudServiceError {
            return serviceError.errorDescription ?? "Unbekannter Fehler."
        }
        return error.localizedDescription
    }
}
