import Foundation

/// KL-ONBOARD-001: Konto und eigenes Restaurant (Blueprint §5,
/// Meilenstein 1.3).
///
/// Der Pitch endet bisher an der Stelle, an der er anfangen sollte: gescannt
/// wird in die eine mitgelieferte Demo-Venue. Diese Schicht macht daraus einen
/// echten Anfang — Konto anlegen, Restaurant anlegen, ab da arbeitet die App
/// mit diesem Restaurant.

struct KitchenLinkVenueSummary: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let slug: String
}

struct KitchenLinkSignUpResult: Equatable, Sendable {
    /// `nil`, wenn die Instanz eine E-Mail-Bestätigung verlangt — dann gibt es
    /// noch keine Sitzung und der Betreiber muss erst bestätigen.
    let session: KitchenLinkCloudSession?
    var needsEmailConfirmation: Bool { session == nil }
}

protocol KitchenLinkVenueOnboardingTransport: Sendable {
    func signUp(
        config: KitchenLinkCloudConfig,
        email: String,
        password: String
    ) async throws -> KitchenLinkSignUpResult

    func createVenue(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        name: String,
        slug: String
    ) async throws -> KitchenLinkVenueSummary

    func suggestSlug(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        slug: String
    ) async throws -> String

    func myVenues(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession
    ) async throws -> [KitchenLinkVenueSummary]
}

extension URLSessionKitchenLinkCloudTransport: KitchenLinkVenueOnboardingTransport {
    func signUp(
        config: KitchenLinkCloudConfig,
        email: String,
        password: String
    ) async throws -> KitchenLinkSignUpResult {
        guard let baseURL = config.baseURL else {
            throw KitchenLinkCloudServiceError.invalidConfiguration
        }
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/v1/signup"))
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(["email": email, "password": password])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0?["msg"] as? String ?? $0?["error_description"] as? String }
            throw KitchenLinkCloudServiceError.server(
                status: http.statusCode,
                message: message ?? "Registrierung fehlgeschlagen (HTTP \(http.statusCode))"
            )
        }

        // Mit aktivierter Bestätigungspflicht antwortet Supabase mit dem
        // angelegten Benutzer, aber ohne Tokens. Das ist kein Fehler — es
        // bedeutet nur: erst bestätigen, dann anmelden.
        struct SignUpResponse: Decodable {
            let accessToken: String?
            let refreshToken: String?
            let expiresIn: Double?
            struct User: Decodable { let id: String }
            let user: User?

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case refreshToken = "refresh_token"
                case expiresIn = "expires_in"
                case user
            }
        }
        guard let decoded = try? JSONDecoder().decode(SignUpResponse.self, from: data) else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        guard let accessToken = decoded.accessToken,
              let refreshToken = decoded.refreshToken,
              let userID = decoded.user?.id else {
            return KitchenLinkSignUpResult(session: nil)
        }
        return KitchenLinkSignUpResult(
            session: KitchenLinkCloudSession(
                accessToken: accessToken,
                refreshToken: refreshToken,
                userID: userID,
                expiresAt: Date().addingTimeInterval(decoded.expiresIn ?? 3600)
            )
        )
    }

    func createVenue(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        name: String,
        slug: String
    ) async throws -> KitchenLinkVenueSummary {
        struct Body: Encodable {
            let p_name: String
            let p_slug: String
        }
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_create_venue",
            bodyData: try JSONEncoder().encode(Body(p_name: name, p_slug: slug))
        )
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = root["venue_id"] as? String,
              let venueName = root["name"] as? String,
              let venueSlug = root["slug"] as? String else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        return KitchenLinkVenueSummary(id: id, name: venueName, slug: venueSlug)
    }

    func suggestSlug(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        slug: String
    ) async throws -> String {
        struct Body: Encodable { let p_slug: String }
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_suggest_venue_slug",
            bodyData: try JSONEncoder().encode(Body(p_slug: slug))
        )
        guard let suggestion = try? JSONDecoder().decode(String.self, from: data),
              !suggestion.isEmpty else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        return suggestion
    }

    func myVenues(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession
    ) async throws -> [KitchenLinkVenueSummary] {
        let data = try await rpcData(
            config: config,
            accessToken: session.accessToken,
            function: "operator_my_venues",
            bodyData: Data("{}".utf8)
        )
        struct Row: Decodable {
            let venueID: String
            let name: String
            let slug: String

            enum CodingKeys: String, CodingKey {
                case venueID = "venue_id"
                case name
                case slug
            }
        }
        guard let rows = try? JSONDecoder().decode([Row].self, from: data) else {
            throw KitchenLinkCloudServiceError.invalidResponse
        }
        return rows.map {
            KitchenLinkVenueSummary(id: $0.venueID, name: $0.name, slug: $0.slug)
        }
    }
}

/// Aus dem Restaurantnamen einen brauchbaren Slug für die Gast-URL machen.
/// Nutzt dieselbe deutsche Umlautbehandlung wie die Menü-Veröffentlichung, damit
/// „Gasthaus Zur Mühle" nicht zu „gasthaus-zur-m-hle" wird.
enum KitchenLinkVenueSlug {
    static func from(name: String) -> String {
        let slug = KitchenLinkMenuPublishPayload.slugify(name)
        // `slugify` fällt bei unbrauchbaren Eingaben auf "artikel" zurück; für
        // eine Venue ist das der falsche Notnagel.
        guard slug != "artikel", slug.count >= 3 else { return "" }
        return String(slug.prefix(60))
    }

    static func isValid(_ slug: String) -> Bool {
        guard slug.count >= 3, slug.count <= 60 else { return false }
        return slug.range(
            of: "^[a-z0-9]+(-[a-z0-9]+)*$",
            options: .regularExpression
        ) != nil
    }
}
