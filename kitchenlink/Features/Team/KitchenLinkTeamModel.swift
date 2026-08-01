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
    /// KL-ROLE-002: die eigene PIN und wie viele es im Lokal gibt.
    @Published private(set) var pinStatus: KitchenLinkManagerPinStatus = .unknown
    /// Das Freigabeprotokoll. Ohne es wäre die Nachvollziehbarkeit aus
    /// Blueprint §8.2 nur eine Zusage in einem Migrationskommentar.
    @Published private(set) var overrides: [KitchenLinkManagerOverrideRecord] = []
    @Published var notice: String?

    @Published var inviteEmail: String = ""
    @Published var inviteRoleKey: String = "service"
    @Published var pinInput: String = ""

    private let config: KitchenLinkCloudConfig
    private let auth: KitchenLinkCloudAuthenticating
    private let transport: KitchenLinkTeamTransport
    private let pin: KitchenLinkManagerPinTransport
    private let store: KitchenLinkCloudCredentialStore
    private let requiresSession: Bool

    init(
        config: KitchenLinkCloudConfig = .sandboxDefault,
        auth: KitchenLinkCloudAuthenticating = URLSessionKitchenLinkCloudTransport(),
        transport: KitchenLinkTeamTransport = URLSessionKitchenLinkCloudTransport(),
        pin: KitchenLinkManagerPinTransport = URLSessionKitchenLinkCloudTransport(),
        store: KitchenLinkCloudCredentialStore = KitchenLinkCloudCredentialStore(),
        requiresSession: Bool = true
    ) {
        self.config = config
        self.auth = auth
        self.transport = transport
        self.pin = pin
        self.store = store
        self.requiresSession = requiresSession
    }

    static func make() -> KitchenLinkTeamModel {
        guard KitchenLinkDesignPreviewConfiguration.shouldSeedDemoTables() else {
            return KitchenLinkTeamModel()
        }
        return KitchenLinkTeamModel(
            transport: KitchenLinkDemoTeamTransport(),
            pin: KitchenLinkDemoManagerPinTransport.shared,
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

    /// Eine PIN, die nichts freigeben könnte, wäre ein stilles Versprechen —
    /// deshalb bietet der Bildschirm sie nur an, wo sie etwas bewirkt.
    var canHoldPin: Bool { myRole.canHoldManagerPin }

    var canSavePin: Bool {
        phase != .working && canHoldPin && KitchenLinkManagerPinRules.isValid(pinInput)
    }

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

            // Vor der Rechtefrage: die eigene PIN darf auch eine
            // Schichtleitung hinterlegen, die diesen Bildschirm sonst nur
            // lesen kann.
            pinStatus = (try? await pin.pinStatus(
                config: config, session: session, venueSlug: config.venueSlug
            )) ?? .unknown

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
            overrides = (try? await pin.recentOverrides(
                config: config, session: session, venueSlug: config.venueSlug, limit: 20
            )) ?? []
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

    // MARK: - Eigene PIN (KL-ROLE-002)

    /// Die PIN gehört der Person, nicht dem Lokal: nur sie selbst setzt sie.
    /// Eine gemeinsame Haus-PIN könnte die Frage „wer hat das freigegeben?"
    /// prinzipiell nicht beantworten (Blueprint §8.2).
    func saveOwnPin() async {
        guard let session = currentSession else {
            phase = .needsSignIn
            return
        }
        if let rejection = KitchenLinkManagerPinRules.rejection(for: pinInput) {
            notice = rejection
            return
        }

        phase = .working
        do {
            try await pin.setPin(
                config: config, session: session,
                venueSlug: config.venueSlug, pin: pinInput
            )
            pinInput = ""
            notice = "PIN hinterlegt. Damit gibst du am Tisch einzelne Aktionen frei."
            await load()
        } catch {
            notice = Self.explain(Self.message(for: error))
            phase = .ready
        }
    }

    func clearOwnPin() async {
        guard let session = currentSession else {
            phase = .needsSignIn
            return
        }
        phase = .working
        do {
            try await pin.clearPin(
                config: config, session: session,
                venueSlug: config.venueSlug, userID: nil
            )
            notice = "PIN gelöscht. Du kannst am Tisch nichts mehr freigeben."
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
        if message.contains("pin_no_authority") {
            return "Eine PIN ergibt nur Sinn, wo sie etwas freigeben kann — "
                + "diese Rolle trägt keines der vier Rechte."
        }
        if message.contains("pin_too_simple") {
            return "Zu einfach. Keine durchgehend gleiche Ziffer und keine "
                + "fortlaufende Zahlenreihe."
        }
        if message.contains("pin_invalid_format") {
            return "Vier bis acht Ziffern."
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
