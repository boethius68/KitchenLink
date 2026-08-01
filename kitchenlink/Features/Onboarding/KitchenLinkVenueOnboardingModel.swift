import Foundation

/// KL-ONBOARD-001: Zustand der Restaurant-Einrichtung.
///
/// Der Ablauf ist bewusst kurz: anmelden oder registrieren, Name eingeben,
/// fertig. Der Slug für die Gast-URL wird aus dem Namen abgeleitet und, falls
/// vergeben, von der Datenbank auf eine freie Variante geschoben — der
/// Betreiber soll keine URL erfinden müssen (Usability-Leitplanke).
@MainActor
final class KitchenLinkVenueOnboardingModel: ObservableObject {
    enum Phase: Equatable {
        case signedOut
        case working
        case ready
        case failed(String)
    }

    @Published private(set) var phase: Phase = .signedOut
    @Published private(set) var venues: [KitchenLinkVenueSummary] = []
    @Published private(set) var activeSlug: String
    @Published var notice: String?
    @Published var restaurantName: String = ""

    private let config: KitchenLinkCloudConfig
    private let auth: KitchenLinkCloudAuthenticating
    private let transport: KitchenLinkVenueOnboardingTransport
    private let store: KitchenLinkCloudCredentialStore
    private let activeVenue: KitchenLinkActiveVenue
    private let demoMode: Bool

    init(
        config: KitchenLinkCloudConfig = .sandboxDefault,
        auth: KitchenLinkCloudAuthenticating = URLSessionKitchenLinkCloudTransport(),
        transport: KitchenLinkVenueOnboardingTransport = URLSessionKitchenLinkCloudTransport(),
        store: KitchenLinkCloudCredentialStore = KitchenLinkCloudCredentialStore(),
        activeVenue: KitchenLinkActiveVenue = .shared,
        /// Nur im Sandbox-Demo: ohne Cloud gibt es keine Sitzung, gegen die man
        /// sich anmelden könnte.
        demoMode: Bool = false
    ) {
        self.demoMode = demoMode
        self.config = config
        self.auth = auth
        self.transport = transport
        self.store = store
        self.activeVenue = activeVenue
        self.activeSlug = activeVenue.slug
    }

    /// Baut das Modell passend zum Sandbox-Demo-Launch-Argument.
    static func make() -> KitchenLinkVenueOnboardingModel {
        guard KitchenLinkDesignPreviewConfiguration.shouldSeedDemoTables() else {
            return KitchenLinkVenueOnboardingModel()
        }
        return KitchenLinkVenueOnboardingModel(
            transport: KitchenLinkDemoOnboardingTransport(),
            store: KitchenLinkCloudCredentialStore(),
            demoMode: true
        )
    }

    var isDemoVenue: Bool { activeSlug == KitchenLinkCloudConfig.demoVenueSlug }

    /// Vorschau der Gast-URL, damit sichtbar ist, was der Name bewirkt.
    var guestURLPreview: String? {
        let slug = KitchenLinkVenueSlug.from(name: restaurantName)
        guard !slug.isEmpty else { return nil }
        return "\(KitchenLinkMenuPublishModel.guestWebHost)/\(slug)/menu"
    }

    var canCreate: Bool {
        phase != .working && !KitchenLinkVenueSlug.from(name: restaurantName).isEmpty
    }

    /// Im Demo-Modus reicht eine leere Sitzung: sie wird nie verwendet.
    private var currentSession: KitchenLinkCloudSession? {
        if let session = store.loadSession() { return session }
        guard demoMode else { return nil }
        return KitchenLinkCloudSession(
            accessToken: "", refreshToken: "", userID: "demo", expiresAt: .distantFuture
        )
    }

    func load() async {
        guard let session = currentSession else {
            phase = .signedOut
            return
        }
        phase = .working
        await loadVenues(session: session)
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
            await loadVenues(session: session)
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    /// Neues Betreiberkonto. Verlangt die Instanz eine E-Mail-Bestätigung, gibt
    /// es noch keine Sitzung — das wird gesagt statt so getan, als wäre man
    /// angemeldet.
    func signUp(email: String, password: String) async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, password.count >= 8 else {
            phase = .failed("E-Mail und ein Passwort mit mindestens 8 Zeichen sind erforderlich.")
            return
        }
        phase = .working
        do {
            let result = try await transport.signUp(
                config: config,
                email: trimmed,
                password: password
            )
            guard let session = result.session else {
                phase = .signedOut
                notice = "Konto angelegt. Bitte bestätige die E-Mail und melde dich dann an."
                return
            }
            store.save(session: session)
            notice = "Konto angelegt."
            await loadVenues(session: session)
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    func createRestaurant() async {
        guard let session = currentSession else {
            phase = .signedOut
            return
        }
        let name = restaurantName.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = KitchenLinkVenueSlug.from(name: name)
        guard !base.isEmpty else {
            notice = "Bitte einen Namen mit mindestens drei Buchstaben oder Ziffern."
            return
        }

        phase = .working
        do {
            // Der Vorschlag kommt aus der Datenbank: nur sie weiß, welcher Slug
            // frei ist. Schlägt der Vorschlag fehl, wird der abgeleitete Slug
            // versucht — die Anlage weist ihn im Zweifel selbst ab.
            let slug = (try? await transport.suggestSlug(
                config: config,
                session: session,
                slug: base
            )) ?? base

            let venue = try await transport.createVenue(
                config: config,
                session: session,
                name: name,
                slug: slug
            )
            activate(venue)
            restaurantName = ""
            notice = "\(venue.name) ist angelegt."
            await loadVenues(session: session)
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    func activate(_ venue: KitchenLinkVenueSummary) {
        activeVenue.set(slug: venue.slug)
        activeSlug = venue.slug
    }

    /// Zurück auf das mitgelieferte Demo-Lokal — der Weg, um die Sandbox
    /// vorzuführen, ohne ein eigenes Restaurant anzulegen.
    func useDemoVenue() {
        activeVenue.reset()
        activeSlug = activeVenue.slug
        notice = "Zurück im Demo-Lokal."
    }

    private func loadVenues(session: KitchenLinkCloudSession) async {
        do {
            venues = try await transport.myVenues(config: config, session: session)
            // Gehört die aktive Venue nicht (mehr) zu diesem Konto, wird auf das
            // erste eigene Restaurant gewechselt statt weiter ins Leere zu zeigen.
            if !venues.isEmpty, !venues.contains(where: { $0.slug == activeSlug }) {
                activate(venues[0])
            }
            phase = .ready
        } catch KitchenLinkCloudServiceError.unauthorized {
            store.clearSession()
            phase = .signedOut
            notice = "Die Anmeldung ist abgelaufen. Bitte erneut anmelden."
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    private static func message(for error: Error) -> String {
        if let serviceError = error as? KitchenLinkCloudServiceError {
            return serviceError.errorDescription ?? "Unbekannter Fehler."
        }
        return error.localizedDescription
    }
}
