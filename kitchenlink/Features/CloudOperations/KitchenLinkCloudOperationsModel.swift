import Foundation

/// KL-CLOUD-001: Zustand des Online-Service auf dem Betreiber-iPhone.
///
/// Das Modell verbindet die Service-Ansicht mit der Supabase-Sandbox:
///  - Nach einmaliger Anmeldung (Sandbox-Operator) pollt es die offenen
///    Venue-Bestellungen und mappt sie in die bestehende
///    `LiveOrderMessage`-Domäne — dieselbe, die auch der lokale Hub nutzt.
///  - Statusübergänge laufen ausschließlich über die Status-RPC; ein Erfolg
///    wird erst nach Serverantwort gemeldet (kein optimistisches ACK).
///  - Solange die Verbindung steht, meldet ein Heartbeat die aktuelle lokale
///    Gast-URL des Foreground-Hubs nach `venue_hub_presence`. Bricht die
///    Internetverbindung ab, bleibt der letzte Eintrag stehen und veraltet —
///    genau daran erkennt das Gast-Web den Ausfall und verweist Gäste auf die
///    lokale Bestellseite.
///  - Beim geordneten Verlassen der Ansicht wird die lokale URL geräumt,
///    damit Gäste nicht auf einen beendeten Hub verwiesen werden.
@MainActor
final class KitchenLinkCloudOperationsModel: ObservableObject {
    enum ConnectionState: Equatable {
        case signedOut
        case connecting
        case connected
        case unreachable(String)
    }

    static let pollInterval: Duration = .seconds(3)
    static let heartbeatInterval: Duration = .seconds(15)

    @Published private(set) var connectionState: ConnectionState = .signedOut
    @Published private(set) var orders: [LiveOrderMessage] = []
    @Published private(set) var venueName: String?
    @Published private(set) var isUpdatingOrder = false
    @Published private(set) var lastActionError: String?

    enum OutboxSyncState: Equatable {
        case idle
        case syncing
        case error(String)
    }
    @Published private(set) var outboxSyncState: OutboxSyncState = .idle
    @Published private(set) var lastOutboxSync: Date?
    @Published private(set) var pendingOutboxCount: Int = 0

    private let transport: any KitchenLinkCloudTransport
    private let store: KitchenLinkCloudCredentialStore
    /// Verbindungsdaten (URL/Anon-Key/Venue) sind in der Sandbox fest
    /// eingebacken (`KitchenLinkCloudConfig.sandboxDefault`); es gibt kein
    /// technisches Einrichtungsformular mehr. Nur die Anmeldung (E-Mail +
    /// Passwort → Sitzung) wird zur Laufzeit hergestellt und gespeichert.
    private let config: KitchenLinkCloudConfig
    /// Exposed so outbox sync can use the current session without duplicating
    /// token refresh logic.
    private(set) var session: KitchenLinkCloudSession?
    private var venue: KitchenLinkCloudVenue?
    private var localGuestURL: String?
    private var pollingTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var outboxTask: Task<Void, Never>?
    /// Called periodically while connected. The closure uses the model's
    /// current config and session to push local events to the cloud.
    /// Returns the number of acknowledged events, or nil if no repository
    /// is available.
    var onDrainOutbox: (@Sendable (KitchenLinkCloudConfig, KitchenLinkCloudSession) async -> Int?)?

    init(
        transport: any KitchenLinkCloudTransport = URLSessionKitchenLinkCloudTransport(),
        defaults: UserDefaults = .standard,
        config: KitchenLinkCloudConfig = .sandboxDefault,
        secrets: any KitchenLinkSecretStore = KeychainSecretStore(service: "kitchenlink.cloud")
    ) {
        self.transport = transport
        self.store = KitchenLinkCloudCredentialStore(
            defaults: defaults,
            secrets: secrets
        )
        self.config = config
        self.session = store.loadSession()
    }

    var isConnected: Bool {
        connectionState == .connected
    }

    var hasStoredSession: Bool {
        session != nil && config.isComplete
    }

    var stateDetail: String {
        switch connectionState {
        case .signedOut:
            return "Online-Service nicht verbunden. Einmal mit dem Betreiber-Konto anmelden — danach verbindet sich dieses iPhone von selbst."
        case .connecting:
            return "Online-Service wird verbunden …"
        case .connected:
            if let venueName {
                return "Online-Bestellungen für \(venueName) sind aktiv."
            }
            return "Online-Bestellungen sind aktiv."
        case .unreachable(let message):
            return message
        }
    }

    // MARK: Lebenszyklus

    /// Verbindet automatisch, wenn Konfiguration und Sitzung vorhanden sind.
    /// Ohne beides bleibt der Zustand `signedOut`; die Ansicht zeigt dann die
    /// einmalige Einrichtung.
    func connectIfPossible() {
        guard pollingTask == nil else { return }
        guard config.isComplete, session != nil else {
            connectionState = .signedOut
            return
        }
        connectionState = .connecting
        startPolling(config: config)
        startHeartbeat(config: config)
        startOutboxSync()
    }

    /// Einmalige Anmeldung mit dem Betreiber-Konto. URL, Anon-Key und Venue
    /// stammen aus dem eingebackenen Standard; hier braucht es nur noch die
    /// zwei Felder, die jede App-Anmeldung hat.
    func signIn(email: String, password: String) async -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            connectionState = .unreachable("Bitte E-Mail und Passwort eingeben.")
            return false
        }

        stopTasks()
        connectionState = .connecting
        do {
            let freshSession = try await transport.signIn(
                config: config,
                email: trimmedEmail,
                password: password
            )
            session = freshSession
            store.save(session: freshSession)
            startPolling(config: config)
            startHeartbeat(config: config)
            startOutboxSync()
            return true
        } catch {
            connectionState = .unreachable(Self.message(for: error))
            return false
        }
    }

    func signOut() {
        stopTasks()
        clearPresenceBestEffort()
        store.clearSession()
        session = nil
        venue = nil
        venueName = nil
        orders = []
        connectionState = .signedOut
        outboxSyncState = .idle
        lastOutboxSync = nil
        pendingOutboxCount = 0
    }

    /// Beendet Polling und Heartbeat. `clearPresence` räumt die lokale URL in
    /// der Cloud (geordnetes Verlassen); ohne Internet scheitert das bewusst
    /// still — der veraltende Heartbeat ist dann genau das gewünschte Signal.
    func stop(clearPresence: Bool) {
        stopTasks()
        if clearPresence {
            clearPresenceBestEffort()
        }
        if connectionState != .signedOut {
            connectionState = hasStoredSession ? .connecting : .signedOut
        }
        orders = []
    }

    /// Aktuelle lokale Gast-URL des Foreground-Hubs (oder nil ohne WLAN).
    /// Wird mit dem nächsten Heartbeat veröffentlicht; bei Änderung sofort.
    func setLocalGuestURL(_ url: URL?) {
        let newValue = url?.absoluteString
        guard newValue != localGuestURL else { return }
        localGuestURL = newValue
        sendHeartbeatNow()
    }

    func containsOrder(id: String) -> Bool {
        orders.contains { $0.id == id }
    }

    // MARK: Bestellungen

    func update(order: LiveOrderMessage, to targetStatus: OrderLifecycleStatus) async -> Bool {
        guard config.isComplete else { return false }
        isUpdatingOrder = true
        defer { isUpdatingOrder = false }
        do {
            _ = try await withSessionRetry(config: config) { session in
                try await self.transport.updateStatus(
                    config: config,
                    session: session,
                    orderID: order.id,
                    targetStatus: targetStatus
                )
            }
            lastActionError = nil
            await refreshOrders()
            return true
        } catch {
            lastActionError = Self.message(for: error)
            return false
        }
    }

    func refreshOrders() async {
        guard config.isComplete else { return }
        do {
            let venue = try await resolvedVenue(config: config)
            let wireOrders = try await withSessionRetry(config: config) { session in
                try await self.transport.loadOrders(
                    config: config,
                    session: session,
                    venueID: venue.id
                )
            }
            orders = wireOrders.compactMap {
                $0.liveOrder(venueID: venue.id, venueName: venue.name)
            }
            venueName = venue.name
            connectionState = .connected
        } catch KitchenLinkCloudServiceError.unauthorized {
            // Refresh ist bereits fehlgeschlagen: Sitzung ist unbrauchbar.
            store.clearSession()
            session = nil
            stopTasks()
            connectionState = .signedOut
        } catch {
            connectionState = .unreachable(Self.message(for: error))
        }
    }

    // MARK: Intern

    private func startPolling(config: KitchenLinkCloudConfig) {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshOrders()
                do {
                    try await Task.sleep(for: Self.pollInterval)
                } catch {
                    return
                }
            }
        }
    }

    private func startHeartbeat(config: KitchenLinkCloudConfig) {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.sendHeartbeat()
                do {
                    try await Task.sleep(for: Self.heartbeatInterval)
                } catch {
                    return
                }
            }
        }
    }

    static let outboxInterval: Duration = .seconds(5)

    private func startOutboxSync() {
        outboxTask?.cancel()
        outboxTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let session = self.session else {
                    try? await Task.sleep(for: Self.outboxInterval)
                    continue
                }
                self.outboxSyncState = .syncing
                do {
                    if let acked = try await self.onDrainOutbox?(self.config, session) {
                        self.lastOutboxSync = Date()
                        self.outboxSyncState = .idle
                        self.pendingOutboxCount = 0
                    } else {
                        self.outboxSyncState = .idle
                    }
                } catch {
                    self.outboxSyncState = .error(error.localizedDescription)
                }
                do {
                    try await Task.sleep(for: Self.outboxInterval)
                } catch {
                    return
                }
            }
        }
    }

    private func stopTasks() {
        pollingTask?.cancel()
        pollingTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        outboxTask?.cancel()
        outboxTask = nil
    }

    private func sendHeartbeatNow() {
        Task { [weak self] in
            await self?.sendHeartbeat()
        }
    }

    /// Intern statt privat, damit Tests den Heartbeat deterministisch
    /// auslösen können (der Timer-Loop bleibt privat).
    func sendHeartbeat() async {
        guard config.isComplete, session != nil else { return }
        // Heartbeat-Fehler ändern den sichtbaren Zustand nicht: der Poll-Loop
        // ist die maßgebliche Verbindungsdiagnose. Ein stiller Fehlschlag hier
        // lässt den Cloud-Eintrag veralten — das gewollte Offline-Signal.
        _ = try? await withSessionRetry(config: config) { session in
            try await self.transport.upsertPresence(
                config: config,
                session: session,
                venueSlug: config.venueSlug,
                deviceID: self.store.deviceID(),
                localGuestURL: self.localGuestURL
            )
        }
    }

    private func clearPresenceBestEffort() {
        guard config.isComplete, let session else { return }
        let transport = self.transport
        let config = self.config
        let deviceID = store.deviceID()
        let slug = config.venueSlug
        localGuestURL = nil
        Task.detached {
            try? await transport.upsertPresence(
                config: config,
                session: session,
                venueSlug: slug,
                deviceID: deviceID,
                localGuestURL: nil
            )
        }
    }

    private func resolvedVenue(config: KitchenLinkCloudConfig) async throws -> KitchenLinkCloudVenue {
        if let venue { return venue }
        guard let resolved = try await transport.resolveVenue(
            config: config,
            slug: config.venueSlug
        ) else {
            throw KitchenLinkCloudServiceError.venueNotFound(config.venueSlug)
        }
        venue = resolved
        return resolved
    }

    /// Führt einen Cloud-Aufruf aus und erneuert die Sitzung genau einmal,
    /// wenn der Server 401 meldet. Schlägt auch das fehl, wird `unauthorized`
    /// weitergereicht (Aufrufer entscheidet über die Abmeldung).
    private func withSessionRetry<T>(
        config: KitchenLinkCloudConfig,
        _ operation: (KitchenLinkCloudSession) async throws -> T
    ) async throws -> T {
        guard let currentSession = session else {
            throw KitchenLinkCloudServiceError.unauthorized
        }
        do {
            return try await operation(currentSession)
        } catch KitchenLinkCloudServiceError.unauthorized {
            let refreshed: KitchenLinkCloudSession
            do {
                refreshed = try await transport.refresh(
                    config: config,
                    refreshToken: currentSession.refreshToken
                )
            } catch let error as KitchenLinkCloudServiceError {
                // GoTrue meldet ein unbrauchbares Refresh-Token als 400, nicht
                // als 401. Beides bedeutet: die Sitzung ist tot. Netzwerkfehler
                // bleiben dagegen Netzwerkfehler (kein fälschliches Abmelden).
                switch error {
                case .unauthorized, .server:
                    throw KitchenLinkCloudServiceError.unauthorized
                default:
                    throw error
                }
            }
            session = refreshed
            store.save(session: refreshed)
            return try await operation(refreshed)
        }
    }

    private static func message(for error: Error) -> String {
        if let cloudError = error as? KitchenLinkCloudServiceError {
            return cloudError.localizedDescription
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return "Keine Internetverbindung. Lokale Bestellungen laufen weiter; Gäste werden auf die lokale Seite verwiesen."
            default:
                break
            }
        }
        return "Cloud nicht erreichbar: \(error.localizedDescription)"
    }
}
