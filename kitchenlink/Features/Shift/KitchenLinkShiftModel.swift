import Foundation

/// KL-SHIFT-001: Zustand der Kasse dieses Betriebstags.
///
/// Der Bildschirm beantwortet eine Frage, bevor er alles andere zeigt: **ist
/// die Kasse offen?** Danach erst kommen Summen, Bewegungen und der Abschluss.
/// Der erwartete Bargeldbestand wird nie hier gerechnet — er kommt mit jedem
/// Bericht aus der Datenbank, weil alle Geräte der Venue auf derselben Schicht
/// arbeiten und ein zweites Gerät jederzeit kassiert haben kann.
@MainActor
final class KitchenLinkShiftModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case ready
        case working
        case needsSignIn
        case failed(String)
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var report: KitchenLinkShiftReport = .none
    @Published private(set) var history: [KitchenLinkShift] = []
    @Published private(set) var lastClose: KitchenLinkShiftClose?
    @Published var notice: String?

    /// Eingaben in Euro als Text: der Betreiber tippt „100" oder „100,50",
    /// nicht 10050. Die Umrechnung passiert an genau einer Stelle.
    @Published var openingCashText: String = ""
    @Published var countedCashText: String = ""
    @Published var closeNote: String = ""
    @Published var movementAmountText: String = ""
    @Published var movementReason: String = ""
    @Published var movementKind: KitchenLinkCashMovementKind = .payout

    private let config: KitchenLinkCloudConfig
    private let auth: KitchenLinkCloudAuthenticating
    private let transport: KitchenLinkShiftTransport
    private let store: KitchenLinkCloudCredentialStore
    private let requiresSession: Bool

    /// Halten die Idempotenz-Schlüssel über Netzwerk-Wiederholungen stabil und
    /// werden erst nach einer bestätigten Buchung verworfen.
    private var openAttemptKey: String?
    private var movementAttemptKey: String?

    init(
        config: KitchenLinkCloudConfig = .sandboxDefault,
        auth: KitchenLinkCloudAuthenticating = URLSessionKitchenLinkCloudTransport(),
        transport: KitchenLinkShiftTransport = URLSessionKitchenLinkCloudTransport(),
        store: KitchenLinkCloudCredentialStore = KitchenLinkCloudCredentialStore(),
        requiresSession: Bool = true
    ) {
        self.config = config
        self.auth = auth
        self.transport = transport
        self.store = store
        self.requiresSession = requiresSession
    }

    /// Baut das Modell passend zum Sandbox-Demo-Launch-Argument.
    static func make() -> KitchenLinkShiftModel {
        guard KitchenLinkDesignPreviewConfiguration.shouldSeedDemoTables() else {
            return KitchenLinkShiftModel()
        }
        return KitchenLinkShiftModel(
            transport: KitchenLinkDemoShiftTransport(),
            requiresSession: false
        )
        // `auth` bleibt der echte Transport: im Demo-Modus wird nie angemeldet.
    }

    /// Im Demo-Modus reicht eine leere Sitzung: sie wird nie verwendet.
    private var currentSession: KitchenLinkCloudSession? {
        if let session = store.loadSession() { return session }
        guard !requiresSession else { return nil }
        return KitchenLinkCloudSession(
            accessToken: "", refreshToken: "", userID: "demo", expiresAt: .distantFuture
        )
    }

    // MARK: - Abgeleitete Anzeige

    var isOpen: Bool { report.isOpen }
    var totals: KitchenLinkShiftTotals { report.totals }

    var openingCashCents: Int { Self.cents(from: openingCashText) ?? 0 }
    var countedCashCents: Int? { Self.cents(from: countedCashText) }
    var movementAmountCents: Int? { Self.cents(from: movementAmountText) }

    /// Was der Abschluss ergäbe, wenn jetzt gezählt würde. Nur eine Vorschau —
    /// gebucht wird ausschließlich, was die Datenbank zurückrechnet.
    var previewVarianceCents: Int? {
        guard let counted = countedCashCents else { return nil }
        return counted - totals.expectedCashCents
    }

    var canClose: Bool {
        phase != .working && isOpen && countedCashCents != nil
    }

    var canBookMovement: Bool {
        guard let amount = movementAmountCents else { return false }
        return phase != .working && isOpen && amount > 0
    }

    /// Ein Abschluss bei noch offenen Rechnungen ist erlaubt, aber fast immer
    /// ein Versehen: das Geld dieser Tische fehlt dann in der Zählung.
    var hasOpenTablesWarning: Bool { isOpen && report.openTableSessions > 0 }

    // MARK: - Laden

    func load() async {
        guard let session = currentSession else {
            phase = .needsSignIn
            return
        }
        if phase != .working { phase = .loading }
        do {
            report = try await transport.loadReport(
                config: config, session: session, venueSlug: config.venueSlug, shiftID: nil
            )
            history = try await transport.recentShifts(
                config: config, session: session, venueSlug: config.venueSlug, limit: 10
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

    // MARK: - Öffnen

    func openShift() async {
        guard let session = currentSession else {
            phase = .needsSignIn
            return
        }
        guard !isOpen else {
            notice = "Es ist bereits eine Schicht offen."
            return
        }
        let key = openAttemptKey ?? UUID().uuidString
        openAttemptKey = key

        phase = .working
        do {
            try await transport.openShift(
                config: config,
                session: session,
                venueSlug: config.venueSlug,
                openingCashCents: openingCashCents,
                idempotencyKey: key
            )
            openAttemptKey = nil
            openingCashText = ""
            notice = "Die Kasse ist offen."
            await load()
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    // MARK: - Bewegung

    func bookMovement() async {
        guard let session = currentSession else {
            phase = .needsSignIn
            return
        }
        guard let amount = movementAmountCents, amount > 0 else {
            notice = "Bitte einen Betrag größer als null eingeben."
            return
        }
        let key = movementAttemptKey ?? UUID().uuidString
        movementAttemptKey = key

        phase = .working
        do {
            try await transport.recordCashMovement(
                config: config,
                session: session,
                venueSlug: config.venueSlug,
                kind: movementKind,
                amountCents: amount,
                reason: movementReason.trimmingCharacters(in: .whitespacesAndNewlines),
                idempotencyKey: key
            )
            movementAttemptKey = nil
            notice = "\(movementKind.label) über "
                + "\(KitchenLinkV2AmountText.euro(cents: amount)) gebucht."
            movementAmountText = ""
            movementReason = ""
            await load()
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    // MARK: - Abschluss

    func closeShift() async {
        guard let session = currentSession else {
            phase = .needsSignIn
            return
        }
        guard let counted = countedCashCents else {
            notice = "Bitte das gezählte Bargeld eingeben."
            return
        }

        phase = .working
        do {
            let result = try await transport.closeShift(
                config: config,
                session: session,
                venueSlug: config.venueSlug,
                countedCashCents: counted,
                note: closeNote.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            lastClose = result
            countedCashText = ""
            closeNote = ""
            notice = result.isBalanced
                ? "Kasse stimmt. Z-Bericht \(result.zNumber) abgeschlossen."
                : "Z-Bericht \(result.zNumber) abgeschlossen, Abweichung "
                    + "\(KitchenLinkV2AmountText.euro(cents: result.varianceCents)) festgehalten."
            await load()
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    func dismissClose() { lastClose = nil }

    // MARK: - Euro-Eingabe

    /// „100", „100,50", „100.50" und „1.234,50" ergeben Cent. Alles andere
    /// ergibt nichts — lieber kein Abschluss als ein falsch gelesener Betrag.
    ///
    /// `nonisolated`, weil hier nur ein String gelesen wird: die Umrechnung
    /// hat auf dem Main Actor nichts zu suchen.
    nonisolated static func cents(from text: String) -> Int? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        trimmed = trimmed.replacingOccurrences(of: "€", with: "")
        trimmed = trimmed.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Tausenderpunkte nur dann entfernen, wenn auch ein Komma da ist —
        // sonst wäre „1.50" fälschlich 150 Euro statt 1,50 Euro.
        if trimmed.contains(",") {
            trimmed = trimmed.replacingOccurrences(of: ".", with: "")
            trimmed = trimmed.replacingOccurrences(of: ",", with: ".")
        }

        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return nil }

        let wholePart = String(parts[0])
        guard !wholePart.isEmpty, wholePart.allSatisfy(\.isNumber),
              let whole = Int(wholePart) else { return nil }

        guard parts.count == 2 else { return whole * 100 }

        let fractionPart = String(parts[1])
        guard fractionPart.count <= 2, fractionPart.allSatisfy(\.isNumber),
              let fraction = Int(fractionPart) else { return nil }

        // „5,5" heißt 5,50 Euro, nicht 5,05.
        let scaled = fractionPart.count == 1 ? fraction * 10 : fraction
        return whole * 100 + scaled
    }

    private static func message(for error: Error) -> String {
        if let serviceError = error as? KitchenLinkCloudServiceError {
            return serviceError.errorDescription ?? "Unbekannter Fehler."
        }
        return error.localizedDescription
    }
}
