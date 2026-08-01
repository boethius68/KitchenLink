import Foundation

/// KL-ONBOARD-001: Sandbox-Demo der Restaurant-Einrichtung ohne Cloud.
///
/// Gleiche Rolle wie die übrigen Demo-Pfade hinter
/// `--kitchenlink-demo-tables`: der Ablauf bleibt vorführ- und prüfbar, bevor
/// die Migrationen auf der Instanz stehen. Er verhält sich wie die Datenbank —
/// belegte Slugs weichen aus, ein zweites Lokal kommt dazu — damit die Demo
/// nichts anderes zeigt als der echte Weg. **Es wird nichts angelegt.**
actor KitchenLinkDemoOnboardingTransport: KitchenLinkVenueOnboardingTransport {
    private var venues: [KitchenLinkVenueSummary]

    init(venues: [KitchenLinkVenueSummary] = []) {
        self.venues = venues
    }

    func signUp(
        config: KitchenLinkCloudConfig,
        email: String,
        password: String
    ) async throws -> KitchenLinkSignUpResult {
        KitchenLinkSignUpResult(
            session: KitchenLinkCloudSession(
                accessToken: "demo",
                refreshToken: "demo",
                userID: "demo-user",
                expiresAt: .distantFuture
            )
        )
    }

    func createVenue(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        name: String,
        slug: String
    ) async throws -> KitchenLinkVenueSummary {
        guard !venues.contains(where: { $0.slug == slug }) else {
            throw KitchenLinkCloudServiceError.server(
                status: 409,
                message: "venue_slug_taken: \(slug) ist schon vergeben"
            )
        }
        let venue = KitchenLinkVenueSummary(id: "demo-\(slug)", name: name, slug: slug)
        venues.append(venue)
        return venue
    }

    func suggestSlug(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        slug: String
    ) async throws -> String {
        var candidate = slug
        var suffix = 1
        while venues.contains(where: { $0.slug == candidate }) {
            suffix += 1
            candidate = "\(slug)-\(suffix)"
        }
        return candidate
    }

    func myVenues(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession
    ) async throws -> [KitchenLinkVenueSummary] {
        venues
    }
}
