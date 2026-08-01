import Foundation

/// KL-TIME-001: Zustand der Stempeluhr.
///
/// Der Bildschirm beantwortet eine Frage, bevor er alles andere zeigt: **bin
/// ich auf der Uhr?** Danach erst kommen Pause, Tagessumme und — für
/// Führungskräfte — wer sonst noch arbeitet.
///
/// Die laufende Uhr zählt lokal weiter, damit die Anzeige nicht stockt; jede
/// Buchung kommt trotzdem vom Server zurück. Das Gerät schätzt, die Datenbank
/// entscheidet.
@MainActor
final class KitchenLinkTimeClockModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case ready
        case working
        case needsSignIn
        case failed(String)
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var status: KitchenLinkTimeStatus = .none
    @Published private(set) var team: [KitchenLinkTeamTimeEntry] = []
    @Published private(set) var myRole: KitchenLinkMyRole = .none
    @Published var notice: String?

    /// Treibt die laufende Anzeige zwischen zwei Serverantworten.
    @Published private(set) var tick: Date = Date()

    @Published var breakKind: KitchenLinkBreakKind = .restBreak

    private let config: KitchenLinkCloudConfig
    private let auth: KitchenLinkCloudAuthenticating
    private let transport: KitchenLinkTimeClockTransport
    private let permissions: KitchenLinkPermissionTransport
    private let store: KitchenLinkCloudCredentialStore
    private let requiresSession: Bool

    init(
        config: KitchenLinkCloudConfig = .sandboxDefault,
        auth: KitchenLinkCloudAuthenticating = URLSessionKitchenLinkCloudTransport(),
        transport: KitchenLinkTimeClockTransport = URLSessionKitchenLinkCloudTransport(),
        permissions: KitchenLinkPermissionTransport = URLSessionKitchenLinkCloudTransport(),
        store: KitchenLinkCloudCredentialStore = KitchenLinkCloudCredentialStore(),
        requiresSession: Bool = true
    ) {
        self.config = config
        self.auth = auth
        self.transport = transport
        self.permissions = permissions
        self.store = store
        self.requiresSession = requiresSession
    }

    static func make() -> KitchenLinkTimeClockModel {
        guard KitchenLinkDesignPreviewConfiguration.shouldSeedDemoTables() else {
            return KitchenLinkTimeClockModel()
        }
        return KitchenLinkTimeClockModel(
            transport: KitchenLinkDemoTimeClockTransport(),
            permissions: KitchenLinkDemoTeamTransport(),
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

    // MARK: - Abgeleitete Anzeige

    var canSeeTeam: Bool { myRole.can(.staffManage) }

    /// Wie lange die laufende Schicht netto dauert — lokal fortgeschrieben.
    /// Während einer Pause steht die Zahl still, weil Pausen nicht zählen.
    var runningNetSeconds: Int {
        guard status.clockedIn, let started = status.startedAt else { return 0 }
        let base = status.current ?? .zero
        guard !status.onBreak else { return base.netSeconds }
        let sinceLoad = Int(tick.timeIntervalSince(started)) - base.grossSeconds
        return base.netSeconds + max(0, sinceLoad)
    }

    var runningBreakSeconds: Int {
        guard status.onBreak, let started = status.breakStartedAt else { return 0 }
        return max(0, Int(tick.timeIntervalSince(started)))
    }

    var todayNetSeconds: Int {
        // Die abgeschlossenen Einträge des Tages plus die laufende Zeit.
        let closed = status.today
            .filter { !$0.isOpen }
            .reduce(0) { $0 + $1.totals.netSeconds }
        return closed + runningNetSeconds
    }

    /// Wer gerade auf der Uhr steht — der Blick, den eine Schichtleitung braucht.
    var onTheClock: [KitchenLinkTeamTimeEntry] { team.filter(\.isOpen) }
    var finishedToday: [KitchenLinkTeamTimeEntry] { team.filter { !$0.isOpen } }

    /// Einträge, die seit über zwölf Stunden offen sind. Fast immer ein
    /// vergessener Ausstempel — und bis er korrigiert ist, kommt die Person
    /// nicht wieder auf die Uhr.
    var forgottenClockOuts: [KitchenLinkTeamTimeEntry] {
        onTheClock.filter { entry in
            guard let started = entry.startedAt else { return false }
            return tick.timeIntervalSince(started) > 12 * 3600
        }
    }

    func advance(to date: Date = Date()) { tick = date }

    // MARK: - Laden

    func load() async {
        guard let session = currentSession else {
            phase = .needsSignIn
            return
        }
        if phase != .working { phase = .loading }
        do {
            myRole = try await permissions.loadMyRole(
                config: config, session: session, venueSlug: config.venueSlug
            )
            status = try await transport.loadStatus(
                config: config, session: session, venueSlug: config.venueSlug
            )
            team = myRole.can(.staffManage)
                ? try await transport.loadTeam(
                    config: config, session: session, venueSlug: config.venueSlug, daysBack: 0
                )
                : []
            tick = Date()
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

    // MARK: - Stempeln

    func toggleClock() async {
        guard let session = currentSession else {
            phase = .needsSignIn
            return
        }
        let wasClockedIn = status.clockedIn
        phase = .working
        do {
            if wasClockedIn {
                try await transport.clockOut(
                    config: config, session: session, venueSlug: config.venueSlug
                )
                notice = "Ausgestempelt."
            } else {
                try await transport.clockIn(
                    config: config, session: session, venueSlug: config.venueSlug
                )
                notice = "Eingestempelt."
            }
            await load()
        } catch {
            notice = Self.explain(Self.message(for: error))
            phase = .ready
        }
    }

    func toggleBreak() async {
        guard let session = currentSession else {
            phase = .needsSignIn
            return
        }
        guard status.clockedIn else {
            notice = "Eine Pause gibt es nur, wenn du eingestempelt bist."
            return
        }
        let wasOnBreak = status.onBreak
        phase = .working
        do {
            if wasOnBreak {
                try await transport.endBreak(
                    config: config, session: session, venueSlug: config.venueSlug
                )
                notice = "Pause beendet."
            } else {
                try await transport.startBreak(
                    config: config, session: session, venueSlug: config.venueSlug, kind: breakKind
                )
                notice = "\(breakKind.label) läuft."
            }
            await load()
        } catch {
            notice = Self.explain(Self.message(for: error))
            phase = .ready
        }
    }

    // MARK: - Korrektur

    func correct(_ entry: KitchenLinkTeamTimeEntry, endedAt: Date, reason: String) async {
        guard let session = currentSession else {
            phase = .needsSignIn
            return
        }
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            notice = "Eine Korrektur ohne Grund ist keine."
            return
        }
        guard let started = entry.startedAt, endedAt > started else {
            notice = "Das Ende muss nach dem Beginn liegen."
            return
        }

        phase = .working
        do {
            try await transport.correct(
                config: config, session: session, venueSlug: config.venueSlug,
                entryID: entry.id, reason: trimmed, endedAt: endedAt
            )
            notice = "\(entry.displayName) wurde ausgestempelt. "
                + "Der ursprüngliche Stand bleibt festgehalten."
            await load()
        } catch {
            notice = Self.explain(Self.message(for: error))
            phase = .ready
        }
    }

    /// Die Absagen der Datenbank in einem Satz, der im Betrieb weiterhilft.
    nonisolated static func explain(_ message: String) -> String {
        if message.contains("time_already_clocked_in") {
            return "Du bist bereits eingestempelt — vielleicht auf einem anderen Gerät."
        }
        if message.contains("time_not_clocked_in") {
            return "Du bist nicht eingestempelt."
        }
        if message.contains("time_break_already_running") {
            return "Die Pause läuft schon."
        }
        if message.contains("time_no_open_break") {
            return "Es läuft keine Pause."
        }
        if message.contains("time_correction_needs_reason") {
            return "Eine Korrektur ohne Grund ist keine."
        }
        if message.contains("time_correction_invalid_range") {
            return "Das Ende muss nach dem Beginn liegen."
        }
        if message.contains("permission_denied") {
            return "Dafür fehlt diesem Zugang das Recht."
        }
        if message.contains("time_forbidden") {
            return "Dieser Zugang gehört nicht zum Personal dieses Restaurants."
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
