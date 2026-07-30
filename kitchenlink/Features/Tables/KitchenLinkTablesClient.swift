import Foundation

/// KL-TABLE-001: Tische und ihre QR-Codes.
///
/// Bis hierher kannte das Produkt keinen Tisch: eine Gastbestellung gehörte dem
/// Lokal, nicht einem Platz im Raum. Diese Schicht macht den Tisch sichtbar und
/// verwaltbar — Grundlage für die gemeinsame Tisch-Session (Blueprint §6.1) und
/// später für die Rechnung.
///
/// Lesen läuft über PostgREST unter der Policy `tables_staff_read`, Schreiben
/// ausschließlich über die drei SECURITY-DEFINER-RPCs aus Migration
/// `20260730120000_table_context.sql`. Der QR-Code enthält nicht die
/// Tischnummer, sondern ein Token aus `qr_tokens`: Umbenennen lässt gedruckte
/// Codes gültig, Rotieren macht genau sie ungültig.

struct KitchenLinkVenueTable: Identifiable, Equatable, Sendable {
    let id: String
    var label: String
    var area: String
    var sortOrder: Int
    var active: Bool
    /// Aktives QR-Token. `nil` bedeutet: dieser Tisch hat (noch) keinen Code.
    var token: String?

    /// Sichtbare Bezeichnung: „3" wird zu „Tisch 3", „Theke" bleibt „Theke".
    var headline: String { KitchenLinkTableLabel.headline(label) }

    /// Bereich für die Gruppierung; leer bleibt ein eigener, benannter Topf.
    var areaOrDefault: String {
        let trimmed = area.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Ohne Bereich" : trimmed
    }
}

/// PostgREST-Zeile inklusive eingebetteter Tokens.
struct KitchenLinkWireTable: Decodable {
    struct WireToken: Decodable {
        let token: String
        let active: Bool
        let mode: String
    }

    let id: String
    let label: String
    let area: String?
    let sortOrder: Int?
    let active: Bool
    let qrTokens: [WireToken]?

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case area
        case sortOrder = "sort_order"
        case active
        case qrTokens = "qr_tokens"
    }

    var table: KitchenLinkVenueTable {
        KitchenLinkVenueTable(
            id: id,
            label: label,
            area: area ?? "",
            sortOrder: sortOrder ?? 0,
            active: active,
            token: qrTokens?.first { $0.active && $0.mode == "table" }?.token
        )
    }
}

/// Antwort von `operator_upsert_table` (jsonb).
struct KitchenLinkTableReceipt: Decodable {
    let tableID: String
    let label: String
    let area: String
    let token: String

    enum CodingKeys: String, CodingKey {
        case tableID = "table_id"
        case label
        case area
        case token
    }
}

protocol KitchenLinkTablesTransport: Sendable {
    func loadTables(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueID: String
    ) async throws -> [KitchenLinkVenueTable]

    func upsertTable(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        tableID: String?,
        label: String,
        area: String,
        sortOrder: Int,
        active: Bool
    ) async throws -> KitchenLinkTableReceipt

    func deleteTable(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        tableID: String
    ) async throws -> Bool

    func rotateTableToken(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        tableID: String
    ) async throws -> String
}

extension URLSessionKitchenLinkCloudTransport: KitchenLinkTablesTransport {
    func loadTables(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueID: String
    ) async throws -> [KitchenLinkVenueTable] {
        let select = "id,label,area,sort_order,active,qr_tokens(token,active,mode)"
        let data = try await restGet(
            config: config,
            accessToken: session.accessToken,
            path: "rest/v1/tables",
            queryItems: [
                URLQueryItem(name: "select", value: select),
                URLQueryItem(name: "venue_id", value: "eq.\(venueID)"),
                URLQueryItem(name: "order", value: "sort_order.asc,label.asc"),
                URLQueryItem(name: "limit", value: "200")
            ]
        )
        guard let rows = try? JSONDecoder().decode([KitchenLinkWireTable].self, from: data) else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        return rows.map(\.table)
    }

    func upsertTable(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        tableID: String?,
        label: String,
        area: String,
        sortOrder: Int,
        active: Bool
    ) async throws -> KitchenLinkTableReceipt {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_label: String
            let p_area: String
            let p_sort_order: Int
            let p_active: Bool
            let p_table_id: String?
        }
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_upsert_table",
            bodyData: try JSONEncoder().encode(
                Body(
                    p_venue_slug: venueSlug,
                    p_label: label,
                    p_area: area,
                    p_sort_order: sortOrder,
                    p_active: active,
                    p_table_id: tableID
                )
            )
        )
        guard let receipt = try? JSONDecoder().decode(KitchenLinkTableReceipt.self, from: data) else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        return receipt
    }

    func deleteTable(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        tableID: String
    ) async throws -> Bool {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_table_id: String
        }
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_delete_table",
            bodyData: try JSONEncoder().encode(
                Body(p_venue_slug: venueSlug, p_table_id: tableID)
            )
        )
        return (try? JSONDecoder().decode(Bool.self, from: data)) ?? false
    }

    func rotateTableToken(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        tableID: String
    ) async throws -> String {
        struct Body: Encodable {
            let p_venue_slug: String
            let p_table_id: String
        }
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_rotate_table_token",
            bodyData: try JSONEncoder().encode(
                Body(p_venue_slug: venueSlug, p_table_id: tableID)
            )
        )
        guard let token = try? JSONDecoder().decode(String.self, from: data),
              !token.isEmpty else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        return token
    }
}

// MARK: - Gast-URL

/// Baut die Adresse, die auf dem Tisch klebt. Bewusst hier und nicht in der
/// Ansicht: dieselbe Regel steht im Gast-Web (`tableGuestUrl`), und beide
/// Seiten müssen denselben Parameter verwenden.
enum KitchenLinkTableGuestURL {
    static let queryParameter = "tisch"

    static func text(host: String, venueSlug: String, token: String) -> String {
        let base = "https://\(host)/\(venueSlug)/menu"
        guard let encoded = token.addingPercentEncoding(
            withAllowedCharacters: .urlQueryValueAllowed
        ) else {
            return base
        }
        return "\(base)?\(queryParameter)=\(encoded)"
    }

    static func url(host: String, venueSlug: String, token: String) -> URL? {
        URL(string: text(host: host, venueSlug: venueSlug, token: token))
    }
}

extension CharacterSet {
    /// `urlQueryAllowed` lässt `&` und `=` durch; für einen einzelnen Wert ist
    /// das falsch.
    static let urlQueryValueAllowed: CharacterSet = {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=?#+")
        return allowed
    }()
}

// MARK: - Modell

@MainActor
final class KitchenLinkTablesModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loading
        case ready
        case needsSignIn
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var tables: [KitchenLinkVenueTable] = []
    /// Rückmeldung der letzten Änderung; wird beim nächsten Vorgang ersetzt.
    @Published var notice: String?

    private let config: KitchenLinkCloudConfig
    private let auth: KitchenLinkCloudAuthenticating
    private let transport: KitchenLinkTablesTransport
    private let venueResolver: KitchenLinkCloudTransport
    private let store: KitchenLinkCloudCredentialStore
    private var venueID: String?

    init(
        config: KitchenLinkCloudConfig = .sandboxDefault,
        auth: KitchenLinkCloudAuthenticating = URLSessionKitchenLinkCloudTransport(),
        transport: KitchenLinkTablesTransport = URLSessionKitchenLinkCloudTransport(),
        venueResolver: KitchenLinkCloudTransport = URLSessionKitchenLinkCloudTransport(),
        store: KitchenLinkCloudCredentialStore = KitchenLinkCloudCredentialStore()
    ) {
        self.config = config
        self.auth = auth
        self.transport = transport
        self.venueResolver = venueResolver
        self.store = store
    }

    var venueSlug: String { config.venueSlug }

    var hasSession: Bool { store.loadSession() != nil }

    /// Tische nach Bereich gruppiert, in der Reihenfolge, in der sie im Betrieb
    /// gelesen werden (Sortierung, dann Bezeichnung).
    var groupedTables: [(area: String, tables: [KitchenLinkVenueTable])] {
        let groups = Dictionary(grouping: tables, by: \.areaOrDefault)
        return groups
            .map { (area: $0.key, tables: $0.value.sorted { left, right in
                left.sortOrder == right.sortOrder
                    ? left.label.localizedStandardCompare(right.label) == .orderedAscending
                    : left.sortOrder < right.sortOrder
            }) }
            .sorted { $0.tables.first?.sortOrder ?? 0 < $1.tables.first?.sortOrder ?? 0 }
    }

    func guestURLText(for table: KitchenLinkVenueTable) -> String? {
        guard let token = table.token else { return nil }
        return KitchenLinkTableGuestURL.text(
            host: KitchenLinkMenuPublishModel.guestWebHost,
            venueSlug: config.venueSlug,
            token: token
        )
    }

    func guestURL(for table: KitchenLinkVenueTable) -> URL? {
        guard let token = table.token else { return nil }
        return KitchenLinkTableGuestURL.url(
            host: KitchenLinkMenuPublishModel.guestWebHost,
            venueSlug: config.venueSlug,
            token: token
        )
    }

    func load() async {
        if KitchenLinkDesignPreviewConfiguration.shouldSeedDemoTables() {
            tables = Self.demoTables
            phase = .ready
            return
        }
        guard let session = store.loadSession() else {
            phase = .needsSignIn
            return
        }
        phase = .loading
        await load(with: session, allowRefresh: true)
    }

    /// Sandbox-Demo für die visuelle Prüfung (Launch-Argument, wie bei Heute,
    /// Küche und Bestand). Deckt die drei sichtbaren Zustände ab: normaler
    /// Tisch mit Code, Tisch ohne Code, stillgelegter Tisch.
    static let demoTables: [KitchenLinkVenueTable] = [
        KitchenLinkVenueTable(id: "demo-1", label: "1", area: "Gastraum", sortOrder: 10, active: true, token: "demo1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c"),
        KitchenLinkVenueTable(id: "demo-2", label: "2", area: "Gastraum", sortOrder: 20, active: true, token: "demo2a2b3c4d5e6f7a8b9c0d1e2f3a4b5c"),
        KitchenLinkVenueTable(id: "demo-3", label: "A1", area: "Terrasse", sortOrder: 30, active: true, token: nil),
        KitchenLinkVenueTable(id: "demo-4", label: "Theke", area: "Bar", sortOrder: 40, active: false, token: "demo4a2b3c4d5e6f7a8b9c0d1e2f3a4b5c")
    ]

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

    func addTable(label: String, area: String) async {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty else {
            notice = "Der Tisch braucht eine Bezeichnung."
            return
        }
        // Neue Tische reihen sich hinten ein, ohne bestehende umzusortieren.
        let nextSortOrder = (tables.map(\.sortOrder).max() ?? 0) + 10
        await perform(description: "\(trimmedLabel) angelegt") { session in
            _ = try await self.transport.upsertTable(
                config: self.config,
                session: session,
                venueSlug: self.config.venueSlug,
                tableID: nil,
                label: trimmedLabel,
                area: area.trimmingCharacters(in: .whitespacesAndNewlines),
                sortOrder: nextSortOrder,
                active: true
            )
        }
    }

    func update(
        table: KitchenLinkVenueTable,
        label: String,
        area: String,
        active: Bool
    ) async {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty else {
            notice = "Der Tisch braucht eine Bezeichnung."
            return
        }
        await perform(description: "\(trimmedLabel) gespeichert") { session in
            _ = try await self.transport.upsertTable(
                config: self.config,
                session: session,
                venueSlug: self.config.venueSlug,
                tableID: table.id,
                label: trimmedLabel,
                area: area.trimmingCharacters(in: .whitespacesAndNewlines),
                sortOrder: table.sortOrder,
                active: active
            )
        }
    }

    func rotateToken(for table: KitchenLinkVenueTable) async {
        await perform(description: "Neuer QR-Code für \(table.headline)") { session in
            _ = try await self.transport.rotateTableToken(
                config: self.config,
                session: session,
                venueSlug: self.config.venueSlug,
                tableID: table.id
            )
        }
    }

    func delete(table: KitchenLinkVenueTable) async {
        await perform(description: "\(table.headline) gelöscht") { session in
            _ = try await self.transport.deleteTable(
                config: self.config,
                session: session,
                venueSlug: self.config.venueSlug,
                tableID: table.id
            )
        }
    }

    /// Gemeinsamer Ablauf für jede Änderung: ausführen, genau einmal nach 401
    /// erneuern, danach neu laden. Ohne Neuladen zeigte die Liste ein
    /// erfundenes Ergebnis statt des tatsächlichen Serverstands.
    private func perform(
        description: String,
        _ action: @escaping (KitchenLinkCloudSession) async throws -> Void
    ) async {
        guard let session = store.loadSession() else {
            phase = .needsSignIn
            return
        }
        do {
            try await action(session)
            notice = description
            await load(with: session, allowRefresh: false)
        } catch KitchenLinkCloudServiceError.unauthorized {
            do {
                let refreshed = try await auth.refresh(
                    config: config,
                    refreshToken: session.refreshToken
                )
                store.save(session: refreshed)
                try await action(refreshed)
                notice = description
                await load(with: refreshed, allowRefresh: false)
            } catch {
                store.clearSession()
                phase = .needsSignIn
                notice = "Die Anmeldung ist abgelaufen. Bitte erneut anmelden."
            }
        } catch {
            notice = Self.message(for: error)
        }
    }

    private func load(with session: KitchenLinkCloudSession, allowRefresh: Bool) async {
        do {
            let venueID = try await resolveVenueID()
            tables = try await transport.loadTables(
                config: config,
                session: session,
                venueID: venueID
            )
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

    private func resolveVenueID() async throws -> String {
        if let venueID { return venueID }
        guard let venue = try await venueResolver.resolveVenue(
            config: config,
            slug: config.venueSlug
        ) else {
            throw KitchenLinkCloudServiceError.server(
                status: 404,
                message: "Die Venue \(config.venueSlug) ist in der Cloud unbekannt."
            )
        }
        venueID = venue.id
        return venue.id
    }

    private static func message(for error: Error) -> String {
        if let serviceError = error as? KitchenLinkCloudServiceError {
            return serviceError.errorDescription ?? "Unbekannter Fehler."
        }
        return error.localizedDescription
    }
}
