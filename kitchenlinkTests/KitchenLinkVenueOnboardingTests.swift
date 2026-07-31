import Foundation
import Testing
@testable import kitchenlink

/// KL-ONBOARD-001: Konto und eigenes Restaurant.
///
/// Der Kern hier ist die Slug-Ableitung (der Betreiber tippt einen Namen, keine
/// URL) und der Zustandswechsel: sobald ein eigenes Restaurant existiert,
/// arbeitet die ganze App darauf — deshalb prüfen die Tests auch, dass die
/// aktive Venue tatsächlich in der Konfiguration ankommt.

private func session() -> KitchenLinkCloudSession {
    KitchenLinkCloudSession(
        accessToken: "at", refreshToken: "rt", userID: "user-1", expiresAt: .distantFuture
    )
}

private func makeStore(withSession: Bool = true) -> KitchenLinkCloudCredentialStore {
    let defaults = UserDefaults(suiteName: "onboard-\(UUID().uuidString)")!
    let store = KitchenLinkCloudCredentialStore(defaults: defaults, secrets: InMemorySecretStore())
    if withSession { store.save(session: session()) }
    return store
}

private func makeActiveVenue() -> KitchenLinkActiveVenue {
    KitchenLinkActiveVenue(defaults: UserDefaults(suiteName: "venue-\(UUID().uuidString)")!)
}

private actor OnboardingSpy: KitchenLinkVenueOnboardingTransport, KitchenLinkCloudAuthenticating {
    var venues: [KitchenLinkVenueSummary]
    var suggestion: String?
    var createError: Error?
    var signUpSession: KitchenLinkCloudSession?
    private(set) var createdNames: [String] = []
    private(set) var createdSlugs: [String] = []
    private(set) var suggestCalls: [String] = []
    private(set) var signUpCalls = 0

    init(venues: [KitchenLinkVenueSummary] = [], suggestion: String? = nil) {
        self.venues = venues
        self.suggestion = suggestion
    }

    func setSuggestion(_ value: String?) { suggestion = value }
    func setCreateError(_ value: Error?) { createError = value }
    func setSignUpSession(_ value: KitchenLinkCloudSession?) { signUpSession = value }

    func signIn(
        config: KitchenLinkCloudConfig, email: String, password: String
    ) async throws -> KitchenLinkCloudSession { session() }

    func refresh(
        config: KitchenLinkCloudConfig, refreshToken: String
    ) async throws -> KitchenLinkCloudSession { session() }

    func signUp(
        config: KitchenLinkCloudConfig, email: String, password: String
    ) async throws -> KitchenLinkSignUpResult {
        signUpCalls += 1
        return KitchenLinkSignUpResult(session: signUpSession)
    }

    func createVenue(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        name: String,
        slug: String
    ) async throws -> KitchenLinkVenueSummary {
        createdNames.append(name)
        createdSlugs.append(slug)
        if let createError { throw createError }
        let venue = KitchenLinkVenueSummary(id: "v-\(slug)", name: name, slug: slug)
        venues.append(venue)
        return venue
    }

    func suggestSlug(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        slug: String
    ) async throws -> String {
        suggestCalls.append(slug)
        guard let suggestion else { throw KitchenLinkCloudServiceError.invalidResponse }
        return suggestion
    }

    func myVenues(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession
    ) async throws -> [KitchenLinkVenueSummary] { venues }
}

@MainActor
private func makeModel(
    spy: OnboardingSpy,
    store: KitchenLinkCloudCredentialStore? = nil,
    activeVenue: KitchenLinkActiveVenue? = nil
) -> KitchenLinkVenueOnboardingModel {
    KitchenLinkVenueOnboardingModel(
        config: .sandboxDefault,
        auth: spy,
        transport: spy,
        store: store ?? makeStore(),
        activeVenue: activeVenue ?? makeActiveVenue()
    )
}

// MARK: - Slug aus dem Namen

@Test func derSlugKommtAusDemNamenMitDeutschenUmlauten() {
    #expect(KitchenLinkVenueSlug.from(name: "Gasthaus Zur Mühle") == "gasthaus-zur-muehle")
    #expect(KitchenLinkVenueSlug.from(name: "Trattoria Bella Vista") == "trattoria-bella-vista")
    #expect(KitchenLinkVenueSlug.from(name: "  Café Öz  ") == "cafe-oez")
}

@Test func unbrauchbareNamenErgebenKeinenSlug() {
    // Wichtig: kein Notnagel-Slug. Lieber nichts anlegen als „artikel".
    #expect(KitchenLinkVenueSlug.from(name: "").isEmpty)
    #expect(KitchenLinkVenueSlug.from(name: "!!!").isEmpty)
    #expect(KitchenLinkVenueSlug.from(name: "ab").isEmpty)
}

@Test func slugGueltigkeitFolgtDerDatenbankregel() {
    #expect(KitchenLinkVenueSlug.isValid("alte-muehle"))
    #expect(KitchenLinkVenueSlug.isValid("lokal-2"))
    #expect(KitchenLinkVenueSlug.isValid("ab") == false)
    #expect(KitchenLinkVenueSlug.isValid("Mit-Grossbuchstaben") == false)
    #expect(KitchenLinkVenueSlug.isValid("mit--doppel") == false)
    #expect(KitchenLinkVenueSlug.isValid("-vorne") == false)
}

// MARK: - Aktive Venue

@Test func ohneEigenesRestaurantBleibtEsBeimDemoLokal() {
    let venue = makeActiveVenue()
    #expect(venue.slug == KitchenLinkCloudConfig.demoVenueSlug)
    #expect(venue.isDemoVenue)
}

@Test func dieAktiveVenueLandetInDerKonfiguration() {
    let defaults = UserDefaults(suiteName: "venue-config-\(UUID().uuidString)")!
    let venue = KitchenLinkActiveVenue(defaults: defaults)
    venue.set(slug: "trattoria-bella-vista")

    #expect(venue.slug == "trattoria-bella-vista")
    #expect(venue.isDemoVenue == false)

    venue.reset()
    #expect(venue.slug == KitchenLinkCloudConfig.demoVenueSlug)
}

@Test func dieGeteilteKonfigurationFolgtDerAktivenVenue() {
    // `sandboxDefault` ist der Standardwert jedes Cloud-Modells. Wenn er der
    // aktiven Venue nicht folgt, arbeitet die halbe App weiter im Demo-Lokal.
    let previous = KitchenLinkActiveVenue.shared.slug
    KitchenLinkActiveVenue.shared.set(slug: "mein-lokal")
    #expect(KitchenLinkCloudConfig.sandboxDefault.venueSlug == "mein-lokal")
    // Instanz und Key bleiben eingebacken.
    #expect(KitchenLinkCloudConfig.sandboxDefault.supabaseURLString
            == KitchenLinkCloudConfig.sandboxURLString)

    KitchenLinkActiveVenue.shared.set(slug: previous)
    #expect(KitchenLinkCloudConfig.sandboxDefault.venueSlug == previous)
}

// MARK: - Anlegen

@MainActor
@Test func einNeuesRestaurantWirdSofortDasAktive() async {
    let spy = OnboardingSpy(suggestion: "trattoria-bella-vista")
    let activeVenue = makeActiveVenue()
    let model = makeModel(spy: spy, activeVenue: activeVenue)
    await model.load()

    model.restaurantName = "Trattoria Bella Vista"
    #expect(model.guestURLPreview?.hasSuffix("/trattoria-bella-vista/menu") == true)

    await model.createRestaurant()

    #expect(await spy.createdNames == ["Trattoria Bella Vista"])
    #expect(await spy.createdSlugs == ["trattoria-bella-vista"])
    #expect(activeVenue.slug == "trattoria-bella-vista")
    #expect(model.activeSlug == "trattoria-bella-vista")
    #expect(model.isDemoVenue == false)
    // Das Feld ist leer für das nächste Lokal.
    #expect(model.restaurantName.isEmpty)
}

@MainActor
@Test func einVergebenerNameWeichtAufDenVorschlagAus() async {
    let spy = OnboardingSpy(suggestion: "trattoria-bella-vista-2")
    let model = makeModel(spy: spy)
    await model.load()
    model.restaurantName = "Trattoria Bella Vista"

    await model.createRestaurant()

    #expect(await spy.suggestCalls == ["trattoria-bella-vista"])
    #expect(await spy.createdSlugs == ["trattoria-bella-vista-2"])
}

@MainActor
@Test func ohneVorschlagWirdDerAbgeleiteteSlugVersucht() async {
    // Die Vorschlagsfunktion darf ausfallen, ohne die Anlage zu blockieren —
    // die Datenbank weist einen belegten Slug ohnehin ab.
    let spy = OnboardingSpy(suggestion: nil)
    let model = makeModel(spy: spy)
    await model.load()
    model.restaurantName = "Gasthaus Zur Mühle"

    await model.createRestaurant()

    #expect(await spy.createdSlugs == ["gasthaus-zur-muehle"])
}

@MainActor
@Test func einNameOhneBuchstabenLegtNichtsAn() async {
    let spy = OnboardingSpy()
    let model = makeModel(spy: spy)
    await model.load()
    model.restaurantName = "!!"

    #expect(model.canCreate == false)
    await model.createRestaurant()

    #expect(await spy.createdNames.isEmpty)
    #expect(model.notice?.contains("mindestens drei") == true)
}

// MARK: - Konto

@MainActor
@Test func ohneAnmeldungWirdNichtGeladen() async {
    let spy = OnboardingSpy()
    let model = makeModel(spy: spy, store: makeStore(withSession: false))

    await model.load()

    #expect(model.phase == .signedOut)
    #expect(model.venues.isEmpty)
}

@MainActor
@Test func einKontoMitBestaetigungspflichtWirdEhrlichGemeldet() async {
    let spy = OnboardingSpy()
    await spy.setSignUpSession(nil)
    let model = makeModel(spy: spy, store: makeStore(withSession: false))

    await model.signUp(email: "neu@restaurant.de", password: "geheim1234")

    #expect(await spy.signUpCalls == 1)
    #expect(model.phase == .signedOut)
    #expect(model.notice?.contains("bestätige") == true)
}

@MainActor
@Test func einZuKurzesPasswortErreichtDenServerNicht() async {
    let spy = OnboardingSpy()
    let model = makeModel(spy: spy, store: makeStore(withSession: false))

    await model.signUp(email: "neu@restaurant.de", password: "kurz")

    #expect(await spy.signUpCalls == 0)
    #expect(model.phase == .failed("E-Mail und ein Passwort mit mindestens 8 Zeichen sind erforderlich."))
}

@MainActor
@Test func eineFremdeAktiveVenueWirdAufDasEigeneLokalKorrigiert() async {
    // Etwa nach einem Kontowechsel: die gespeicherte Venue gehört diesem Konto
    // nicht — dann zeigt die App nicht weiter ins Leere.
    let spy = OnboardingSpy(venues: [
        KitchenLinkVenueSummary(id: "v1", name: "Mein Lokal", slug: "mein-lokal")
    ])
    let activeVenue = makeActiveVenue()
    activeVenue.set(slug: "fremdes-lokal")
    let model = makeModel(spy: spy, activeVenue: activeVenue)

    await model.load()

    #expect(model.activeSlug == "mein-lokal")
    #expect(activeVenue.slug == "mein-lokal")
}

@MainActor
@Test func zurueckInsDemoLokal() async {
    let spy = OnboardingSpy(venues: [
        KitchenLinkVenueSummary(id: "v1", name: "Mein Lokal", slug: "mein-lokal")
    ])
    let activeVenue = makeActiveVenue()
    let model = makeModel(spy: spy, activeVenue: activeVenue)
    await model.load()

    model.useDemoVenue()

    #expect(activeVenue.slug == KitchenLinkCloudConfig.demoVenueSlug)
    #expect(model.isDemoVenue)
}
