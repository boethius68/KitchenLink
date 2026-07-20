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
    static let sandboxDefault = KitchenLinkCloudConfig(
        supabaseURLString: "https://rjxlzqtaxqstctrrlqre.supabase.co",
        anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJqeGx6cXRheHFzdGN0cnJscXJlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQzMTc5NTksImV4cCI6MjA5OTg5Mzk1OX0.lxml_3ka6lNeXlodO3JH5ExbWRtdbAInC1wpceC0uoQ",
        venueSlug: "alte-muehle"
    )
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

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case quantity
        case unitPriceCents = "unit_price_cents"
        case kind
    }
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
            tableID: nil,
            tableLabel: nil,
            customerNote: customerNote ?? "",
            items: items.map { item in
                LiveOrderLine(
                    id: item.id,
                    name: item.name,
                    quantity: item.quantity,
                    unitPriceCents: item.unitPriceCents,
                    kind: MenuItemKind(rawValue: item.kind) ?? .food
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
        let select = "id,created_at,status,total_cents,currency,service_mode,"
            + "customer_note,source_device,"
            + "order_items(id,name,quantity,unit_price_cents,kind)"
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
/// Menü-Veröffentlichung. Die RPC `operator_publish_menu` erwartet ein
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
            function: "operator_publish_menu",
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

/// Persistenz für Konfiguration und Sitzung. Bewusst UserDefaults: die
/// Sandbox speichert nur die Sandbox-Operator-Sitzung (Access-/Refresh-Token),
/// nie das Passwort. Vor einem Produktionspfad gehört das in die Keychain —
/// als Sandbox-Grenze im Handoff dokumentiert.
struct KitchenLinkCloudCredentialStore {
    static let sessionKey = "kitchenlink.cloud.session.v1"
    static let deviceKey = "kitchenlink.cloud.deviceID.v1"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func loadSession() -> KitchenLinkCloudSession? {
        guard let data = defaults.data(forKey: Self.sessionKey) else { return nil }
        return try? decoder.decode(KitchenLinkCloudSession.self, from: data)
    }

    func save(session: KitchenLinkCloudSession) {
        guard let data = try? encoder.encode(session) else { return }
        defaults.set(data, forKey: Self.sessionKey)
    }

    func clearSession() {
        defaults.removeObject(forKey: Self.sessionKey)
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
