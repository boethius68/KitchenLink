import Foundation
import Testing
@testable import kitchenlink

/// KL-MENU-005: Scan-zu-Publish-Brücke.
///
/// Zwei Ebenen ohne Netzwerk: der reine Nutzlast-Bau (stabile, eindeutige Slugs
/// aus deutschen Namen, Kind-/Allergen-Mapping) und das Publish-Model gegen
/// einen Transport-Spy (gespeicherte Sitzung, Anmeldung, genau-einmaliger
/// 401-Refresh, tote Sitzung, leere Zugangsdaten).

// MARK: - Test-Helfer

private func section(
    id: String,
    title: String,
    kind: MenuItemKind,
    items: [MenuItemData]
) -> MenuSectionData {
    MenuSectionData(id: id, title: title, subtitle: "", kind: kind, items: items)
}

private func item(
    id: String,
    name: String,
    priceCents: Int,
    kind: MenuItemKind = .food,
    allergenCodes: String? = nil
) -> MenuItemData {
    MenuItemData(
        id: id,
        name: name,
        description: "Beschreibung",
        priceCents: priceCents,
        kind: kind,
        allergenCodes: allergenCodes
    )
}

/// Erfüllt genau die schmalen Protokolle, die das Publish-Model nutzt.
private actor MenuPublishSpy: KitchenLinkCloudAuthenticating, KitchenLinkMenuPublishTransport {
    var signInResult: KitchenLinkCloudSession?
    var signInError: KitchenLinkCloudServiceError?
    var refreshResult: KitchenLinkCloudSession?
    var refreshError: KitchenLinkCloudServiceError?
    var publishResult: KitchenLinkMenuPublishReceipt
    var failFirstPublishUnauthorized = false

    private(set) var signInCalls = 0
    private(set) var refreshCalls = 0
    private(set) var publishCalls = 0
    private(set) var lastPublishedMenu: KitchenLinkPublishMenu?
    private(set) var lastPublishAccessToken: String?

    init(
        signInResult: KitchenLinkCloudSession? = nil,
        refreshResult: KitchenLinkCloudSession? = nil,
        publishResult: KitchenLinkMenuPublishReceipt = KitchenLinkMenuPublishReceipt(
            menuID: "menu-1", categoryCount: 1, itemCount: 1
        )
    ) {
        self.signInResult = signInResult
        self.refreshResult = refreshResult
        self.publishResult = publishResult
    }

    func setFailFirstPublishUnauthorized(_ value: Bool) { failFirstPublishUnauthorized = value }
    func setRefreshError(_ error: KitchenLinkCloudServiceError) { refreshError = error }
    func setSignInError(_ error: KitchenLinkCloudServiceError) { signInError = error }

    func signIn(
        config: KitchenLinkCloudConfig,
        email: String,
        password: String
    ) async throws -> KitchenLinkCloudSession {
        signInCalls += 1
        if let signInError { throw signInError }
        guard let signInResult else { throw KitchenLinkCloudServiceError.invalidResponse }
        return signInResult
    }

    func refresh(
        config: KitchenLinkCloudConfig,
        refreshToken: String
    ) async throws -> KitchenLinkCloudSession {
        refreshCalls += 1
        if let refreshError { throw refreshError }
        guard let refreshResult else { throw KitchenLinkCloudServiceError.invalidResponse }
        return refreshResult
    }

    func publishMenu(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        menu: KitchenLinkPublishMenu
    ) async throws -> KitchenLinkMenuPublishReceipt {
        publishCalls += 1
        lastPublishedMenu = menu
        lastPublishAccessToken = session.accessToken
        if failFirstPublishUnauthorized && publishCalls == 1 {
            throw KitchenLinkCloudServiceError.unauthorized
        }
        return publishResult
    }
}

private func makeStore() -> KitchenLinkCloudCredentialStore {
    let defaults = UserDefaults(suiteName: "menu-publish-\(UUID().uuidString)")!
    return KitchenLinkCloudCredentialStore(defaults: defaults)
}

private func session(access: String, refresh: String = "rt") -> KitchenLinkCloudSession {
    KitchenLinkCloudSession(
        accessToken: access,
        refreshToken: refresh,
        userID: "user-1",
        expiresAt: .distantFuture
    )
}

// MARK: - Nutzlast-Bau

@Test func slugifyExpandsGermanUmlautsAndDiacritics() {
    #expect(KitchenLinkMenuPublishPayload.slugify("Kürbissuppe") == "kuerbissuppe")
    #expect(KitchenLinkMenuPublishPayload.slugify("Käsespätzle") == "kaesespaetzle")
    #expect(KitchenLinkMenuPublishPayload.slugify("Crème brûlée") == "creme-brulee")
    #expect(KitchenLinkMenuPublishPayload.slugify("Große Weißwurst") == "grosse-weisswurst")
}

@Test func slugifyCollapsesSeparatorsAndTrims() {
    #expect(KitchenLinkMenuPublishPayload.slugify("  Flammkuchen – Elsässer Art! ") == "flammkuchen-elsaesser-art")
    #expect(KitchenLinkMenuPublishPayload.slugify("0,4 l Limonade") == "0-4-l-limonade")
}

@Test func slugifyEmptyFallsBackToArtikel() {
    #expect(KitchenLinkMenuPublishPayload.slugify("•••") == "artikel")
    #expect(KitchenLinkMenuPublishPayload.slugify("") == "artikel")
}

@Test func buildDisambiguatesDuplicateSlugs() {
    let sections = [
        section(id: "s1", title: "Küche", kind: .food, items: [
            item(id: "i1", name: "Tagessuppe", priceCents: 500),
            item(id: "i2", name: "Tagessuppe", priceCents: 550),
            item(id: "i3", name: "Tagessuppe", priceCents: 600)
        ])
    ]
    let payload = KitchenLinkMenuPublishPayload.build(from: sections)
    let slugs = payload.categories.flatMap { $0.items.map(\.slug) }
    #expect(slugs == ["tagessuppe", "tagessuppe-2", "tagessuppe-3"])
    #expect(Set(slugs).count == slugs.count)
}

@Test func buildMapsKindAllergensAndDropsEmptySections() {
    let sections = [
        section(id: "food", title: "Küche", kind: .food, items: [
            item(id: "i1", name: "Zander", priceCents: 2350, kind: .food, allergenCodes: "a,d")
        ]),
        section(id: "drinks", title: "Getränke", kind: .drink, items: [
            item(id: "i2", name: "Hauslimonade", priceCents: 490, kind: .drink)
        ]),
        section(id: "empty", title: "Leer", kind: .food, items: [])
    ]
    let payload = KitchenLinkMenuPublishPayload.build(from: sections)

    #expect(payload.categories.count == 2) // leere Sektion entfällt
    #expect(payload.categories[0].kind == "food")
    #expect(payload.categories[1].kind == "drink")
    #expect(payload.categories[0].items[0].allergenCodes == ["a", "d"])
    #expect(payload.categories[1].items[0].allergenCodes.isEmpty)
    #expect(payload.itemCount == 2)
}

@Test func buildUsesDisplayNameWithoutTrailingAllergenCodes() {
    // Name mit eingebetteten Codes -> displayName trennt sie ab; der Slug und
    // der veröffentlichte Name enthalten die Codes nicht mehr.
    let sections = [
        section(id: "s1", title: "Küche", kind: .food, items: [
            item(id: "i1", name: "Schnitzel (a,c)", priceCents: 1490)
        ])
    ]
    let payload = KitchenLinkMenuPublishPayload.build(from: sections)
    let published = payload.categories[0].items[0]
    #expect(published.name == "Schnitzel")
    #expect(published.slug == "schnitzel")
    #expect(published.allergenCodes == ["a", "c"])
}

// MARK: - Model

private func onePayload() -> KitchenLinkPublishMenu {
    KitchenLinkMenuPublishPayload.build(from: [
        section(id: "s1", title: "Küche", kind: .food, items: [
            item(id: "i1", name: "Kürbissuppe", priceCents: 690)
        ])
    ])
}

@Test func publishWithStoredSessionSucceeds() async {
    let store = makeStore()
    store.save(session: session(access: "at1"))
    let spy = MenuPublishSpy(
        publishResult: KitchenLinkMenuPublishReceipt(menuID: "m9", categoryCount: 1, itemCount: 1)
    )
    let model = await KitchenLinkMenuPublishModel(
        payload: onePayload(), auth: spy, publisher: spy, store: store
    )

    await model.publishUsingStoredSession()

    let calls = await spy.publishCalls
    let menu = await spy.lastPublishedMenu
    let token = await spy.lastPublishAccessToken
    #expect(calls == 1)
    #expect(token == "at1")
    #expect(menu?.categories.first?.items.first?.slug == "kuerbissuppe")
    if case .published(let receipt) = await model.phase {
        #expect(receipt.menuID == "m9")
    } else {
        Issue.record("erwartete .published, war \(await model.phase)")
    }
}

@Test func publishWithoutStoredSessionSignsInFirst() async {
    let store = makeStore() // keine Sitzung
    let spy = MenuPublishSpy(signInResult: session(access: "fresh"))
    let model = await KitchenLinkMenuPublishModel(
        payload: onePayload(), auth: spy, publisher: spy, store: store
    )

    #expect(await model.hasSession == false)
    await model.signInAndPublish(email: "op@kitchenlink.test", password: "secret")

    let signIns = await spy.signInCalls
    let publishes = await spy.publishCalls
    let token = await spy.lastPublishAccessToken
    #expect(signIns == 1)
    #expect(publishes == 1)
    #expect(token == "fresh")
    #expect(store.loadSession()?.accessToken == "fresh") // Sitzung wurde persistiert
    if case .published = await model.phase {} else {
        Issue.record("erwartete .published, war \(await model.phase)")
    }
}

@Test func unauthorizedPublishRefreshesExactlyOnceAndRetries() async {
    let store = makeStore()
    store.save(session: session(access: "stale", refresh: "rt-good"))
    let spy = MenuPublishSpy(refreshResult: session(access: "renewed"))
    await spy.setFailFirstPublishUnauthorized(true)
    let model = await KitchenLinkMenuPublishModel(
        payload: onePayload(), auth: spy, publisher: spy, store: store
    )

    await model.publishUsingStoredSession()

    let refreshes = await spy.refreshCalls
    let publishes = await spy.publishCalls
    let token = await spy.lastPublishAccessToken
    #expect(refreshes == 1)
    #expect(publishes == 2)          // erster 401, zweiter mit erneuerter Sitzung
    #expect(token == "renewed")
    #expect(store.loadSession()?.accessToken == "renewed")
    if case .published = await model.phase {} else {
        Issue.record("erwartete .published, war \(await model.phase)")
    }
}

@Test func deadRefreshTokenClearsSessionAndFails() async {
    let store = makeStore()
    store.save(session: session(access: "stale", refresh: "rt-dead"))
    let spy = MenuPublishSpy()
    await spy.setFailFirstPublishUnauthorized(true)
    // Refresh scheitert (totes Token wird von GoTrue als 400 gemeldet).
    await spy.setRefreshError(KitchenLinkCloudServiceError.server(status: 400, message: "invalid"))
    let model = await KitchenLinkMenuPublishModel(
        payload: onePayload(), auth: spy, publisher: spy, store: store
    )

    await model.publishUsingStoredSession()

    #expect(store.loadSession() == nil) // Sitzung verworfen
    if case .failed = await model.phase {} else {
        Issue.record("erwartete .failed, war \(await model.phase)")
    }
}

@Test func emptyCredentialsFailWithoutNetwork() async {
    let store = makeStore()
    let spy = MenuPublishSpy(signInResult: session(access: "fresh"))
    let model = await KitchenLinkMenuPublishModel(
        payload: onePayload(), auth: spy, publisher: spy, store: store
    )

    await model.signInAndPublish(email: "  ", password: "")

    let signIns = await spy.signInCalls
    let publishes = await spy.publishCalls
    #expect(signIns == 0)
    #expect(publishes == 0)
    if case .failed = await model.phase {} else {
        Issue.record("erwartete .failed, war \(await model.phase)")
    }
}
