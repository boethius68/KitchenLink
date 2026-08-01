import Foundation

/// KL-CLOUD-001: Betreiberseitiger Zugriff auf die Supabase-Sandbox.
///
/// Der Client spricht die gleiche Instanz an, die das öffentliche Gast-Web
/// bedient (EU-Frankfurt, konfiguriert vom Nutzer). Er ist bewusst dünn:
/// Anmeldung über Supabase Auth (E-Mail/Passwort des Sandbox-Operators),
/// Lesen der Venue-Bestellungen über PostgREST (RLS-Policy
/// `orders_staff_read`), Statusübergänge und Presence-Heartbeat
/// ausschließlich über die beiden SECURITY-DEFINER-RPCs aus Migration
/// `20260719100000_operator_cloud_orders.sql`.
///
/// Es gibt keine hartkodierte Projekt-URL und keinen hartkodierten Key:
/// die Konfiguration kommt einmalig vom Nutzer (Service-Ansicht) und liegt
/// im UserDefaults-Sandbox-Speicher. Sitzungen werden über das Refresh-Token
/// erneuert; das Passwort selbst wird nie persistiert.

struct KitchenLinkCloudConfig: Codable, Equatable {
    var supabaseURLString: String
    var anonKey: String
    var venueSlug: String

    var baseURL: URL? {
        let trimmed = supabaseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: candidate),
              url.scheme?.lowercased() == "https",
              url.host != nil else {
            return nil
        }
        return url
    }

    var isComplete: Bool {
        baseURL != nil
            && !anonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !venueSlug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Sandbox-Standard: dieselbe öffentliche Supabase-Instanz, die auch das
    /// Gast-Web bedient. URL und Anon-Key sind bewusst KEINE Geheimnisse — der
    /// Anon-Key wird ohnehin an jeden Browser ausgeliefert, der die Website
    /// öffnet. Sie sind fest eingebacken, damit im Betrieb niemand technische
    /// Verbindungsdaten eintippt; die Venue ist in der Sandbox `alte-muehle`.
    /// Für eine spätere Multi-Venue-/Produktionsphase ersetzt eine echte
    /// Konfigurationsquelle diese Konstante.
    /// Instanz und Anon-Key bleiben eingebacken (die Sandbox hat genau eine
    /// Instanz), **die Venue nicht mehr**: seit KL-ONBOARD-001 legt ein
    /// Betreiber sein eigenes Restaurant an, und ab dann arbeitet die App mit
    /// dessen Slug. Ohne eigenes Restaurant bleibt es beim Demo-Lokal.
    static var sandboxDefault: KitchenLinkCloudConfig {
        KitchenLinkCloudConfig(
            supabaseURLString: sandboxURLString,
            anonKey: sandboxAnonKey,
            venueSlug: KitchenLinkActiveVenue.shared.slug
        )
    }

    static let sandboxURLString = "https://rjxlzqtaxqstctrrlqre.supabase.co"
    static let sandboxAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJqeGx6cXRheHFzdGN0cnJscXJlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQzMTc5NTksImV4cCI6MjA5OTg5Mzk1OX0.lxml_3ka6lNeXlodO3JH5ExbWRtdbAInC1wpceC0uoQ"
    static let demoVenueSlug = "alte-muehle"
}

/// Welches Restaurant dieses Gerät gerade bedient (KL-ONBOARD-001).
///
/// Bewusst kein Geheimnis und deshalb in `UserDefaults`: der Slug steht ohnehin
/// in der öffentlichen Gast-URL. Er wird beim Anlegen eines Restaurants und bei
/// der Anmeldung gesetzt — nie von Hand eingetippt (Usability-Leitplanke).
final class KitchenLinkActiveVenue: @unchecked Sendable {
    static let shared = KitchenLinkActiveVenue()

    private static let key = "kitchenlink.activeVenueSlug.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var slug: String {
        defaults.string(forKey: Self.key) ?? KitchenLinkCloudConfig.demoVenueSlug
    }

    /// True, solange der Betreiber noch beim mitgelieferten Demo-Lokal ist.
    var isDemoVenue: Bool { slug == KitchenLinkCloudConfig.demoVenueSlug }

    func set(slug newSlug: String) {
        let trimmed = newSlug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        defaults.set(trimmed, forKey: Self.key)
    }

    func reset() {
        defaults.removeObject(forKey: Self.key)
    }
}

struct KitchenLinkCloudSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let userID: String
    let expiresAt: Date
}

struct KitchenLinkCloudVenue: Equatable {
    let id: String
    let name: String
}

struct KitchenLinkCloudWireOrderItem: Codable, Equatable {
    let id: String
    let name: String
    let quantity: Int
    let unitPriceCents: Int
    let kind: String
    /// KL-STATION-001: gesetzt, sobald die zuständige Station freigegeben hat.
    let readyAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case quantity
        case unitPriceCents = "unit_price_cents"
        case kind
        case readyAt = "ready_at"
    }
}

/// Eingebetteter Tisch der Bestellung (KL-TABLE-001). PostgREST liefert die
/// Beziehung `orders.table_id -> tables.id` als eingebettetes Objekt.
struct KitchenLinkCloudWireOrderTable: Codable, Equatable {
    let label: String
    let area: String?
}

struct KitchenLinkCloudWireOrder: Codable, Equatable {
    let id: String
    let createdAt: String
    let status: String
    let totalCents: Int
    let currency: String
    let serviceMode: String?
    let customerNote: String?
    let sourceDevice: String?
    let tableID: String?
    let table: KitchenLinkCloudWireOrderTable?
    let items: [KitchenLinkCloudWireOrderItem]

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case status
        case totalCents = "total_cents"
        case currency
        case serviceMode = "service_mode"
        case customerNote = "customer_note"
        case sourceDevice = "source_device"
        case tableID = "table_id"
        case table = "tables"
        case items = "order_items"
    }

    /// Mappt eine PostgREST-Zeile auf die bestehende Bestelldomäne. Zeilen mit
    /// unbekanntem Status oder unlesbarem Zeitstempel werden verworfen statt
    /// geraten (kein zweites Bestellmodell, keine erfundenen Werte).
    func liveOrder(venueID: String, venueName: String) -> LiveOrderMessage? {
        guard let lifecycleStatus = OrderLifecycleStatus(rawValue: status),
              let createdAtDate = KitchenLinkCloudTimestamp.parse(createdAt) else {
            return nil
        }
        return LiveOrderMessage(
            id: id,
            createdAt: createdAtDate,
            sourceDevice: "Online · #\(id.prefix(8))",
            venueID: venueID,
            venueName: venueName,
            serviceMode: serviceMode.flatMap(ServiceMode.init(rawValue:)),
            tableID: tableID,
            tableLabel: table?.label,
            customerNote: customerNote ?? "",
            items: items.map { item in
                LiveOrderLine(
                    id: item.id,
                    name: item.name,
                    quantity: item.quantity,
                    unitPriceCents: item.unitPriceCents,
                    kind: MenuItemKind(rawValue: item.kind) ?? .food,
                    readyAt: item.readyAt.flatMap(KitchenLinkCloudTimestamp.parse)
                )
            },
            totalCents: totalCents,
            status: lifecycleStatus
        )
    }
}

struct KitchenLinkCloudStatusReceipt: Codable, Equatable {
    let orderID: String
    let status: String
    let replayed: Bool

    enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case status
        case replayed
    }
}

enum KitchenLinkCloudTimestamp {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let whole: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// PostgREST liefert `timestamptz` mit oder ohne Sekundenbruchteile
    /// (z. B. `2026-07-19T12:34:56.789012+00:00`).
    static func parse(_ value: String) -> Date? {
        fractional.date(from: value) ?? whole.date(from: value)
    }
}

enum KitchenLinkCloudServiceError: LocalizedError, Equatable {
    case invalidConfiguration
    case unauthorized
    case venueNotFound(String)
    case server(status: Int, message: String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Bitte Supabase-URL, Anon-Key und Venue prüfen."
        case .unauthorized:
            return "Die Anmeldung ist abgelaufen. Bitte erneut anmelden."
        case .venueNotFound(let slug):
            return "Venue \(slug) wurde in der Cloud nicht gefunden."
        case .server(_, let message):
            return message
        case .invalidResponse:
            return "Unerwartete Antwort der Cloud."
        }
    }
}

/// Nur Anmeldung und Sitzungserneuerung. Schmal genug, dass Nebenpfade wie die
/// Menü-Veröffentlichung (KL-MENU-005) davon abhängen können, ohne die vollen
/// Bestell-Methoden zu benötigen. `KitchenLinkCloudTransport` verfeinert es.
protocol KitchenLinkCloudAuthenticating: Sendable {
    func signIn(
        config: KitchenLinkCloudConfig,
        email: String,
        password: String
    ) async throws -> KitchenLinkCloudSession

    func refresh(
        config: KitchenLinkCloudConfig,
        refreshToken: String
    ) async throws -> KitchenLinkCloudSession
}

protocol KitchenLinkCloudTransport: KitchenLinkCloudAuthenticating {
    func resolveVenue(
        config: KitchenLinkCloudConfig,
        slug: String
    ) async throws -> KitchenLinkCloudVenue?

    func loadOrders(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueID: String
    ) async throws -> [KitchenLinkCloudWireOrder]

    func updateStatus(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        orderID: String,
        targetStatus: OrderLifecycleStatus
    ) async throws -> KitchenLinkCloudStatusReceipt

    func upsertPresence(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        deviceID: String,
        localGuestURL: String?
    ) async throws

    func createOrder(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        id: String,
        createdAt: Date,
        sourceDevice: String,
        totalCents: Int,
        serviceMode: String,
        customerNote: String,
        itemsJSON: Data,
        /// Tisch der Kellnerbestellung (KL-TABLE-002); `nil` für Theke,
        /// Abholung oder Telefon.
        tableID: String?
    ) async throws -> Bool
}

struct URLSessionKitchenLinkCloudTransport: KitchenLinkCloudTransport {
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: Auth

    private struct AuthUser: Codable {
        let id: String
    }

    private struct AuthResponse: Codable {
        let accessToken: String
        let refreshToken: String
        let expiresIn: Double
        let user: AuthUser

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case user
        }
    }

    func signIn(
        config: KitchenLinkCloudConfig,
        email: String,
        password: String
    ) async throws -> KitchenLinkCloudSession {
        try await token(
            config: config,
            grantType: "password",
            body: ["email": email, "password": password]
        )
    }

    func refresh(
        config: KitchenLinkCloudConfig,
        refreshToken: String
    ) async throws -> KitchenLinkCloudSession {
        try await token(
            config: config,
            grantType: "refresh_token",
            body: ["refresh_token": refreshToken]
        )
    }

    private func token(
        config: KitchenLinkCloudConfig,
        grantType: String,
        body: [String: String]
    ) async throws -> KitchenLinkCloudSession {
        guard let baseURL = config.baseURL,
              var components = URLComponents(
                url: baseURL.appendingPathComponent("auth/v1/token"),
                resolvingAgainstBaseURL: false
              ) else {
            throw KitchenLinkCloudServiceError.invalidConfiguration
        }
        components.queryItems = [URLQueryItem(name: "grant_type", value: grantType)]
        guard let url = components.url else {
            throw KitchenLinkCloudServiceError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        guard let auth = try? decoder.decode(AuthResponse.self, from: data) else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        return KitchenLinkCloudSession(
            accessToken: auth.accessToken,
            refreshToken: auth.refreshToken,
            userID: auth.user.id,
            expiresAt: Date().addingTimeInterval(auth.expiresIn)
        )
    }

    // MARK: REST

    private struct VenueRow: Codable {
        let id: String
        let name: String
    }

    func resolveVenue(
        config: KitchenLinkCloudConfig,
        slug: String
    ) async throws -> KitchenLinkCloudVenue? {
        let data = try await get(
            config: config,
            bearer: config.anonKey,
            path: "rest/v1/venues",
            queryItems: [
                URLQueryItem(name: "select", value: "id,name"),
                URLQueryItem(name: "slug", value: "eq.\(slug)"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        guard let rows = try? decoder.decode([VenueRow].self, from: data) else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        return rows.first.map { KitchenLinkCloudVenue(id: $0.id, name: $0.name) }
    }

    func loadOrders(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueID: String
    ) async throws -> [KitchenLinkCloudWireOrder] {
        // Bewusst nur `label`: `tables.area` kommt erst mit der Tisch-Migration
        // (20260730120000). Ein Betrieb, der die App aktualisiert hat, aber die
        // Migration noch nicht, soll seine Bestellungen weiter sehen — die
        // Bestellliste braucht den Bereich nicht.
        // `ready_at` je Position kommt erst mit der Stationsmigration
        // (20260731140000). Ein Betrieb, der die App aktualisiert hat, aber die
        // Migration noch nicht, soll seine Bestellungen weiter sehen — deshalb
        // ein Versuch mit, ein Rückfall ohne. Sobald die Migration steht,
        // greift wieder der erste Weg.
        do {
            return try await loadOrders(
                config: config,
                session: session,
                venueID: venueID,
                includeStationReadiness: true
            )
        } catch let error as KitchenLinkCloudServiceError {
            guard case .server(_, let message) = error,
                  message.contains("ready_at") else {
                throw error
            }
            return try await loadOrders(
                config: config,
                session: session,
                venueID: venueID,
                includeStationReadiness: false
            )
        }
    }

    private func loadOrders(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueID: String,
        includeStationReadiness: Bool
    ) async throws -> [KitchenLinkCloudWireOrder] {
        let itemColumns = includeStationReadiness
            ? "id,name,quantity,unit_price_cents,kind,ready_at"
            : "id,name,quantity,unit_price_cents,kind"
        let select = "id,created_at,status,total_cents,currency,service_mode,"
            + "customer_note,source_device,table_id,"
            + "tables(label),"
            + "order_items(\(itemColumns))"
        let data = try await get(
            config: config,
            bearer: session.accessToken,
            path: "rest/v1/orders",
            queryItems: [
                URLQueryItem(name: "select", value: select),
                URLQueryItem(name: "venue_id", value: "eq.\(venueID)"),
                URLQueryItem(name: "status", value: "in.(pending,accepted,preparing,ready)"),
                URLQueryItem(name: "order", value: "created_at.asc"),
                URLQueryItem(name: "limit", value: "100")
            ]
        )
        guard let orders = try? decoder.decode([KitchenLinkCloudWireOrder].self, from: data) else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        return orders
    }

    func updateStatus(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        orderID: String,
        targetStatus: OrderLifecycleStatus
    ) async throws -> KitchenLinkCloudStatusReceipt {
        let data = try await rpc(
            config: config,
            session: session,
            function: "operator_update_order_status",
            body: [
                "p_order_id": orderID,
                "p_target_status": targetStatus.rawValue
            ]
        )
        guard let rows = try? decoder.decode([KitchenLinkCloudStatusReceipt].self, from: data),
              let receipt = rows.first else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        return receipt
    }

    func upsertPresence(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        deviceID: String,
        localGuestURL: String?
    ) async throws {
        _ = try await rpc(
            config: config,
            session: session,
            function: "operator_upsert_hub_presence",
            body: [
                "p_venue_slug": venueSlug,
                "p_device_id": deviceID,
                "p_local_guest_url": localGuestURL
            ]
        )
    }

    func createOrder(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        id: String,
        createdAt: Date,
        sourceDevice: String,
        totalCents: Int,
        serviceMode: String,
        customerNote: String,
        itemsJSON: Data,
        tableID: String?
    ) async throws -> Bool {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let createdAtISO = iso.string(from: createdAt)
        struct CreateOrderBody: Encodable {
            let p_venue_slug: String
            let p_id: String
            let p_created_at: String
            let p_source_device: String
            let p_total_cents: Int
            let p_service_mode: String
            let p_customer_note: String
            /// Sent as raw JSON array, not a string — PostgREST maps it directly
            /// to the `jsonb` function parameter.
            let p_items: JSONValue
            let p_table_id: String?
        }
        let items: JSONValue = try JSONDecoder().decode(JSONValue.self, from: itemsJSON)
        let body = CreateOrderBody(
            p_venue_slug: venueSlug,
            p_id: id,
            p_created_at: createdAtISO,
            p_source_device: sourceDevice,
            p_total_cents: totalCents,
            p_service_mode: serviceMode,
            p_customer_note: customerNote,
            p_items: items,
            p_table_id: tableID
        )
        _ = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_create_order",
            bodyData: try JSONEncoder().encode(body)
        )
        return true
    }

    /// A JSON value wrapper that encodes/decodes to the natural JSON
    /// representation (array, object, string, number, bool, null).
    private enum JSONValue: Codable {
        case array([JSONValue])
        case object([String: JSONValue])
        case string(String)
        case number(Double)
        case bool(Bool)
        case null

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let arr = try? container.decode([JSONValue].self) {
                self = .array(arr)
            } else if let obj = try? container.decode([String: JSONValue].self) {
                self = .object(obj)
            } else if let str = try? container.decode(String.self) {
                self = .string(str)
            } else if let num = try? container.decode(Double.self) {
                self = .number(num)
            } else if let bool = try? container.decode(Bool.self) {
                self = .bool(bool)
            } else if container.decodeNil() {
                self = .null
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "unknown JSON value")
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .array(let arr): try container.encode(arr)
            case .object(let obj): try container.encode(obj)
            case .string(let str): try container.encode(str)
            case .number(let num): try container.encode(num)
            case .bool(let bool): try container.encode(bool)
            case .null: try container.encodeNil()
            }
        }
    }

    // MARK: Request-Bausteine

    private func get(
        config: KitchenLinkCloudConfig,
        bearer: String,
        path: String,
        queryItems: [URLQueryItem]
    ) async throws -> Data {
        guard let baseURL = config.baseURL,
              var components = URLComponents(
                url: baseURL.appendingPathComponent(path),
                resolvingAgainstBaseURL: false
              ) else {
            throw KitchenLinkCloudServiceError.invalidConfiguration
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw KitchenLinkCloudServiceError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    private func rpc(
        config: KitchenLinkCloudConfig,
        session urlSessionSession: KitchenLinkCloudSession,
        function: String,
        body: [String: String?]
    ) async throws -> Data {
        try await rpcData(
            config: config,
            accessToken: urlSessionSession.accessToken,
            function: function,
            bodyData: try JSONEncoder().encode(body)
        )
    }

    /// Gemeinsames PostgREST-GET für Erweiterungen in anderen Dateien (Swift
    /// `private` ist dateiweit, `get` selbst bleibt daher intern). Genutzt von
    /// der Tischverwaltung (KL-TABLE-001).
    func restGet(
        config: KitchenLinkCloudConfig,
        accessToken: String,
        path: String,
        queryItems: [URLQueryItem]
    ) async throws -> Data {
        try await get(
            config: config,
            bearer: accessToken,
            path: path,
            queryItems: queryItems
        )
    }

    /// Gemeinsamer RPC-POST für Bodies mit beliebiger (auch verschachtelter)
    /// Struktur. `rpc` reicht ein flaches `[String: String?]` durch; die
    /// Menü-Veröffentlichung reicht eine JSON-kodierte Nutzlast mit
    /// eingebettetem `p_menu` durch.
    func rpcData(
        config: KitchenLinkCloudConfig,
        accessToken: String,
        function: String,
        bodyData: Data,
        timeout: TimeInterval = 10
    ) async throws -> Data {
        guard let baseURL = config.baseURL else {
            throw KitchenLinkCloudServiceError.invalidConfiguration
        }
        let url = baseURL.appendingPathComponent("rest/v1/rpc/\(function)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    private struct PostgRESTError: Codable {
        let message: String?
        let msg: String?
        let errorDescription: String?

        enum CodingKeys: String, CodingKey {
            case message
            case msg
            case errorDescription = "error_description"
        }

        var text: String? {
            message ?? msg ?? errorDescription
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        guard !(200..<300).contains(http.statusCode) else { return }

        if http.statusCode == 401 {
            throw KitchenLinkCloudServiceError.unauthorized
        }
        let message = (try? JSONDecoder().decode(PostgRESTError.self, from: data))?.text
        throw KitchenLinkCloudServiceError.server(
            status: http.statusCode,
            message: message ?? "Cloud-Fehler (HTTP \(http.statusCode))"
        )
    }
}

/// KL-MENU-005: dieselbe Transport-Implementierung bedient auch die
/// Menü-Veröffentlichung. Die RPC `operator_publish_menu_v2` erwartet ein
/// verschachteltes `p_menu`-JSON, daher der Encodable-Body statt des flachen
/// `[String: String?]`.
extension URLSessionKitchenLinkCloudTransport: KitchenLinkMenuPublishTransport {
    func publishMenu(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        menu: KitchenLinkPublishMenu
    ) async throws -> KitchenLinkMenuPublishReceipt {
        struct PublishBody: Encodable {
            let p_venue_slug: String
            let p_menu: KitchenLinkPublishMenu
        }
        let bodyData = try JSONEncoder().encode(
            PublishBody(p_venue_slug: venueSlug, p_menu: menu)
        )
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_publish_menu_v2",
            bodyData: bodyData,
            timeout: 15
        )
        guard let rows = try? JSONDecoder().decode([KitchenLinkMenuPublishReceipt].self, from: data),
              let receipt = rows.first else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        return receipt
    }
}

/// Persistenz für Konfiguration und Sitzung.
/// Die Supabase-Sitzung (Access-/Refresh-Token) liegt **ausschließlich** im
/// Secret-Speicher (Produktpfad: Keychain). Sie wird nicht zusätzlich in
/// UserDefaults geschrieben — eine Kopie im Klartext würde die Migration
/// aufheben. Nicht-sensitive Konfiguration (Device-ID) bleibt in UserDefaults.
struct KitchenLinkCloudCredentialStore {
    static let secretSessionAccount = "session.v1"
    static let deviceKey = "kitchenlink.cloud.deviceID.v1"
    static let legacyUserDefaultsSessionKey = "kitchenlink.cloud.session.v1"

    private let defaults: UserDefaults
    let secrets: any KitchenLinkSecretStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        defaults: UserDefaults = .standard,
        secrets: any KitchenLinkSecretStore = KeychainSecretStore(service: "kitchenlink.cloud")
    ) {
        self.defaults = defaults
        self.secrets = secrets
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    private func loadFromSecrets() -> KitchenLinkCloudSession? {
        guard let data = secrets.load(account: Self.secretSessionAccount) else { return nil }
        return try? decoder.decode(KitchenLinkCloudSession.self, from: data)
    }

    func loadSession() -> KitchenLinkCloudSession? {
        if let session = loadFromSecrets() { return session }
        return migrateLegacySession()
    }

    func save(session: KitchenLinkCloudSession) {
        guard let data = try? encoder.encode(session) else { return }
        secrets.save(data, account: Self.secretSessionAccount)
    }

    func clearSession() {
        secrets.delete(account: Self.secretSessionAccount)
        defaults.removeObject(forKey: Self.legacyUserDefaultsSessionKey)
    }

    /// Hebt eine Sitzung aus der alten UserDefaults-Ablage einmalig in den
    /// Secret-Speicher und entfernt die Klartextkopie.
    private func migrateLegacySession() -> KitchenLinkCloudSession? {
        guard let data = defaults.data(forKey: Self.legacyUserDefaultsSessionKey),
              let session = try? decoder.decode(KitchenLinkCloudSession.self, from: data)
        else { return nil }
        save(session: session)
        defaults.removeObject(forKey: Self.legacyUserDefaultsSessionKey)
        return session
    }

    func deviceID() -> String {
        if let saved = defaults.string(forKey: Self.deviceKey) {
            return saved
        }
        let fresh = "ios-service-\(UUID().uuidString.lowercased())"
        defaults.set(fresh, forKey: Self.deviceKey)
        return fresh
    }
}
