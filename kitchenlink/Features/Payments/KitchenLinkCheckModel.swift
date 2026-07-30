import Foundation

/// KL-PAY-001: Zustand des Kassierens an einem Tisch.
///
/// Die Auswahl der Positionen ist der Kern: „getrennt zahlen" heißt im Betrieb
/// nicht „durch drei teilen", sondern „diese Gänge zahle ich". Die App führt
/// deshalb die Auswahl, nennt den daraus folgenden Betrag — und lässt die
/// Datenbank denselben Betrag noch einmal selbst ausrechnen, bevor gebucht
/// wird. Weicht er ab, wird nicht gebucht.
@MainActor
final class KitchenLinkCheckModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loading
        case ready
        case paying
        case needsSignIn
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var check: KitchenLinkCheck = .empty
    @Published private(set) var lastReceipt: KitchenLinkPaymentReceipt?
    @Published var selectedItemIDs: Set<String> = []
    @Published var method: KitchenLinkPaymentMethod = .cash
    @Published var tipCents: Int = 0
    @Published var notice: String?

    let table: KitchenLinkVenueTable

    private let config: KitchenLinkCloudConfig
    private let auth: KitchenLinkCloudAuthenticating
    private let transport: KitchenLinkCheckTransport
    private let provider: KitchenLinkPaymentProviding
    private let store: KitchenLinkCloudCredentialStore
    /// Hält den Idempotenz-Schlüssel über Netzwerk-Wiederholungen stabil und
    /// wird erst nach einer bestätigten Zahlung verworfen.
    private var attemptKey: String?

    /// `requiresSession` ist nur im Sandbox-Demo-Modus false: dort gibt es
    /// keine Cloud, gegen die man sich anmelden könnte.
    private let requiresSession: Bool

    init(
        table: KitchenLinkVenueTable,
        config: KitchenLinkCloudConfig = .sandboxDefault,
        auth: KitchenLinkCloudAuthenticating = URLSessionKitchenLinkCloudTransport(),
        transport: KitchenLinkCheckTransport = URLSessionKitchenLinkCloudTransport(),
        provider: KitchenLinkPaymentProviding = KitchenLinkSandboxPaymentProvider(),
        store: KitchenLinkCloudCredentialStore = KitchenLinkCloudCredentialStore(),
        requiresSession: Bool = true
    ) {
        self.table = table
        self.config = config
        self.auth = auth
        self.transport = transport
        self.provider = provider
        self.store = store
        self.requiresSession = requiresSession
    }

    /// Baut das Modell passend zum Sandbox-Demo-Launch-Argument.
    static func make(for table: KitchenLinkVenueTable) -> KitchenLinkCheckModel {
        guard KitchenLinkDesignPreviewConfiguration.shouldSeedDemoTables() else {
            return KitchenLinkCheckModel(table: table)
        }
        return KitchenLinkCheckModel(
            table: table,
            transport: KitchenLinkDemoCheckTransport(),
            requiresSession: false
        )
    }

    /// Im Demo-Modus reicht eine leere Sitzung: sie wird nie verwendet.
    private var currentSession: KitchenLinkCloudSession? {
        if let session = store.loadSession() { return session }
        guard !requiresSession else { return nil }
        return KitchenLinkCloudSession(
            accessToken: "", refreshToken: "", userID: "demo", expiresAt: .distantFuture
        )
    }

    var openItems: [KitchenLinkCheckItem] { check.items.filter { !$0.paid } }
    var paidItems: [KitchenLinkCheckItem] { check.items.filter(\.paid) }

    /// Betrag der aktuellen Auswahl; ohne Auswahl der gesamte offene Betrag.
    var selectionCents: Int {
        guard !selectedItemIDs.isEmpty else { return check.openCents }
        return check.items
            .filter { selectedItemIDs.contains($0.id) && !$0.paid }
            .reduce(0) { $0 + $1.lineTotalCents }
    }

    var payableCents: Int { selectionCents + tipCents }

    var isPartialPayment: Bool {
        !selectedItemIDs.isEmpty && selectionCents < check.openCents
    }

    var canPay: Bool {
        phase != .paying && check.tableSessionID != nil && selectionCents > 0
    }

    func toggle(_ item: KitchenLinkCheckItem) {
        guard !item.paid else { return }
        if selectedItemIDs.contains(item.id) {
            selectedItemIDs.remove(item.id)
        } else {
            selectedItemIDs.insert(item.id)
        }
        // Eine geänderte Auswahl ist ein anderer Vorgang.
        attemptKey = nil
    }

    func selectAllOpenItems() {
        selectedItemIDs = Set(openItems.map(\.id))
        attemptKey = nil
    }

    func clearSelection() {
        selectedItemIDs = []
        attemptKey = nil
    }

    func load() async {
        guard let session = currentSession else {
            phase = .needsSignIn
            return
        }
        if phase != .paying { phase = .loading }
        await load(with: session, allowRefresh: true)
    }

    func signIn(email: String, password: String) async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !password.isEmpty else {
            phase = .failed("E-Mail und Passwort sind erforderlich.")
            return
        }
        phase = .loading
        do {
            let session = try await auth.signIn(config: config, email: trimmed, password: password)
            store.save(session: session)
            await load(with: session, allowRefresh: false)
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    /// Kassiert die aktuelle Auswahl. Erst der Anbieter (bei Karte/Tap to Pay),
    /// dann die Buchung — eine abgelehnte Autorisierung erzeugt keine Zahlung.
    func pay(allowRefresh: Bool = true) async {
        guard let sessionID = check.tableSessionID else {
            notice = "Für diesen Tisch ist keine Rechnung offen."
            return
        }
        guard let cloudSession = currentSession else {
            phase = .needsSignIn
            return
        }
        guard selectionCents > 0 else {
            notice = "Es ist nichts ausgewählt und nichts offen."
            return
        }

        let amount = selectionCents
        let items = selectedItemIDs.isEmpty ? [] : Array(selectedItemIDs)
        let key = attemptKey ?? Self.makeAttemptKey()
        attemptKey = key

        phase = .paying
        var reference: String?
        if method.requiresProvider {
            do {
                let authorization = try await provider.authorize(
                    amountCents: amount,
                    tipCents: tipCents,
                    method: method
                )
                reference = authorization.reference
            } catch {
                phase = .ready
                notice = "Zahlung abgelehnt: \(Self.message(for: error))"
                return
            }
        }

        do {
            let receipt = try await transport.recordPayment(
                config: config,
                session: cloudSession,
                venueSlug: config.venueSlug,
                tableSessionID: sessionID,
                method: method,
                idempotencyKey: key,
                tipCents: tipCents,
                orderItemIDs: items,
                // Ohne Positionsauswahl ist das der Teilbetrag; mit Auswahl
                // rechnet die Datenbank selbst und prüft diesen Wert nur
                // dagegen. Weichen beide ab, bucht sie nicht.
                amountCents: amount,
                providerReference: reference
            )
            lastReceipt = receipt
            attemptKey = nil
            selectedItemIDs = []
            tipCents = 0
            notice = receipt.replayed
                ? "Diese Zahlung war bereits gebucht."
                : nil
            await load(with: cloudSession, allowRefresh: false)
        } catch KitchenLinkCloudServiceError.unauthorized where allowRefresh {
            await refreshAndRetryPayment(session: cloudSession)
        } catch {
            phase = .ready
            notice = Self.message(for: error)
        }
    }

    func refund(paymentID: String, reason: String) async {
        guard let session = currentSession else {
            phase = .needsSignIn
            return
        }
        do {
            try await transport.refundPayment(
                config: config,
                session: session,
                venueSlug: config.venueSlug,
                paymentID: paymentID,
                reason: reason
            )
            lastReceipt = nil
            notice = "Zahlung storniert."
            await load(with: session, allowRefresh: false)
        } catch {
            notice = Self.message(for: error)
        }
    }

    private func refreshAndRetryPayment(session: KitchenLinkCloudSession) async {
        do {
            let refreshed = try await auth.refresh(
                config: config,
                refreshToken: session.refreshToken
            )
            store.save(session: refreshed)
            // Derselbe Idempotenz-Schlüssel: der zweite Versuch ist kein
            // zweiter Vorgang, selbst wenn der erste die Datenbank erreicht
            // hat. Genau einmal erneuern — sonst liefe ein dauerhaft
            // abgelehnter Zugriff im Kreis.
            await pay(allowRefresh: false)
        } catch {
            store.clearSession()
            phase = .needsSignIn
            notice = "Die Anmeldung ist abgelaufen. Bitte erneut anmelden."
        }
    }

    private func load(with session: KitchenLinkCloudSession, allowRefresh: Bool) async {
        do {
            check = try await transport.loadCheck(
                config: config,
                session: session,
                venueSlug: config.venueSlug,
                tableID: table.id
            )
            selectedItemIDs = selectedItemIDs.intersection(openItems.map(\.id))
            phase = .ready
        } catch KitchenLinkCloudServiceError.unauthorized where allowRefresh {
            do {
                let refreshed = try await auth.refresh(
                    config: config,
                    refreshToken: session.refreshToken
                )
                store.save(session: refreshed)
                await load(with: refreshed, allowRefresh: false)
            } catch {
                store.clearSession()
                phase = .needsSignIn
            }
        } catch {
            phase = .failed(Self.message(for: error))
        }
    }

    /// Ein Schlüssel je Kassiervorgang. Er wird gehalten, solange derselbe
    /// Vorgang wiederholt wird (Netzwerkfehler, Sitzungserneuerung), und
    /// verworfen, sobald sich die Auswahl ändert oder eine Zahlung bestätigt
    /// ist. Zwei gleiche Runden hintereinander sind zwei Zahlungen — deshalb
    /// zufällig statt aus dem Inhalt abgeleitet.
    static func makeAttemptKey() -> String {
        "pay-" + UUID().uuidString.lowercased()
    }

    private static func message(for error: Error) -> String {
        if let serviceError = error as? KitchenLinkCloudServiceError {
            return serviceError.errorDescription ?? "Unbekannter Fehler."
        }
        return error.localizedDescription
    }
}
