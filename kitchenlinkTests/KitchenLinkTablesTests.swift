import Foundation
import Testing
@testable import kitchenlink

/// KL-TABLE-001: Tischkontext auf der Betreiberseite.
///
/// Ohne Netzwerk geprüft: Bezeichnungsregel, Gast-URL (muss zum Gast-Web
/// passen), Zeilen-Mapping inklusive Token-Auswahl, Tisch an der
/// Cloud-Bestellung und das Modell gegen einen Transport-Spy — inklusive
/// genau-einmaligem 401-Refresh und totem Refresh-Token.
///
/// Was diese Tests NICHT beweisen: die RPC-Ausführung selbst. Dafür gibt es
/// `scripts/verify-supabase-migrations.sh` gegen ein echtes PostgreSQL.

// MARK: - Helfer

private func session(access: String, refresh: String = "rt") -> KitchenLinkCloudSession {
    KitchenLinkCloudSession(
        accessToken: access,
        refreshToken: refresh,
        userID: "user-1",
        expiresAt: .distantFuture
    )
}

private func makeStore() -> KitchenLinkCloudCredentialStore {
    let defaults = UserDefaults(suiteName: "tables-\(UUID().uuidString)")!
    return KitchenLinkCloudCredentialStore(defaults: defaults, secrets: InMemorySecretStore())
}

private func table(
    id: String = "t1",
    label: String = "3",
    area: String = "Gastraum",
    sortOrder: Int = 30,
    active: Bool = true,
    token: String? = "tok-3"
) -> KitchenLinkVenueTable {
    KitchenLinkVenueTable(
        id: id,
        label: label,
        area: area,
        sortOrder: sortOrder,
        active: active,
        token: token
    )
}

private actor TablesSpy: KitchenLinkCloudAuthenticating, KitchenLinkTablesTransport, KitchenLinkCloudTransport {
    var tables: [KitchenLinkVenueTable]
    var refreshResult: KitchenLinkCloudSession?
    var signInResult: KitchenLinkCloudSession?
    var refreshError: KitchenLinkCloudServiceError?
    var failFirstUpsertUnauthorized = false
    var upsertError: KitchenLinkCloudServiceError?

    private(set) var upsertCalls: [(tableID: String?, label: String, area: String, sortOrder: Int, active: Bool)] = []
    private(set) var deleteCalls: [String] = []
    private(set) var rotateCalls: [String] = []
    private(set) var refreshCalls = 0
    private(set) var signInCalls = 0
    private(set) var loadCalls = 0
    private(set) var lastLoadAccessToken: String?

    init(tables: [KitchenLinkVenueTable] = []) {
        self.tables = tables
    }

    func setTables(_ value: [KitchenLinkVenueTable]) { tables = value }
    func setRefreshResult(_ value: KitchenLinkCloudSession?) { refreshResult = value }
    func setSignInResult(_ value: KitchenLinkCloudSession?) { signInResult = value }
    func setRefreshError(_ value: KitchenLinkCloudServiceError?) { refreshError = value }
    func setFailFirstUpsertUnauthorized(_ value: Bool) { failFirstUpsertUnauthorized = value }
    func setUpsertError(_ value: KitchenLinkCloudServiceError?) { upsertError = value }

    // Auth

    func signIn(
        config: KitchenLinkCloudConfig,
        email: String,
        password: String
    ) async throws -> KitchenLinkCloudSession {
        signInCalls += 1
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

    // Venue

    func resolveVenue(
        config: KitchenLinkCloudConfig,
        slug: String
    ) async throws -> KitchenLinkCloudVenue? {
        KitchenLinkCloudVenue(id: "venue-1", name: "Gasthaus Alte Mühle")
    }

    func loadOrders(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueID: String
    ) async throws -> [KitchenLinkCloudWireOrder] { [] }

    func updateStatus(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        orderID: String,
        targetStatus: OrderLifecycleStatus
    ) async throws -> KitchenLinkCloudStatusReceipt {
        KitchenLinkCloudStatusReceipt(orderID: orderID, status: targetStatus.rawValue, replayed: false)
    }

    func upsertPresence(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        deviceID: String,
        localGuestURL: String?
    ) async throws {}

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
    ) async throws -> Bool { true }

    // Tische

    func loadTables(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueID: String
    ) async throws -> [KitchenLinkVenueTable] {
        loadCalls += 1
        lastLoadAccessToken = session.accessToken
        return tables
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
        upsertCalls.append((tableID, label, area, sortOrder, active))
        if let upsertError { throw upsertError }
        if failFirstUpsertUnauthorized && upsertCalls.count == 1 {
            throw KitchenLinkCloudServiceError.unauthorized
        }
        let receipt = KitchenLinkTableReceipt(
            tableID: tableID ?? "neu",
            label: label,
            area: area,
            token: "tok-neu"
        )
        tables.append(
            KitchenLinkVenueTable(
                id: receipt.tableID,
                label: label,
                area: area,
                sortOrder: sortOrder,
                active: active,
                token: receipt.token
            )
        )
        return receipt
    }

    func deleteTable(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        tableID: String
    ) async throws -> Bool {
        deleteCalls.append(tableID)
        tables.removeAll { $0.id == tableID }
        return true
    }

    func rotateTableToken(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        tableID: String
    ) async throws -> String {
        rotateCalls.append(tableID)
        return "tok-rotiert"
    }
}

@MainActor
private func makeModel(
    spy: TablesSpy,
    store: KitchenLinkCloudCredentialStore
) -> KitchenLinkTablesModel {
    KitchenLinkTablesModel(
        config: .sandboxDefault,
        auth: spy,
        transport: spy,
        venueResolver: spy,
        store: store
    )
}

// MARK: - Bezeichnung und URL

@Test func tischnummerBekommtPraefixNameNicht() {
    #expect(KitchenLinkTableLabel.headline("3") == "Tisch 3")
    #expect(KitchenLinkTableLabel.headline("12b") == "Tisch 12b")
    // Bereichskürzel sind im Betrieb üblich (Bereich A, Tisch 1).
    #expect(KitchenLinkTableLabel.headline("A1") == "Tisch A1")
    #expect(KitchenLinkTableLabel.headline("Theke") == "Theke")
    #expect(KitchenLinkTableLabel.headline("  Terrasse links  ") == "Terrasse links")
    // Ein Name mit Nummer bleibt ein Name: „Tisch Terrasse 1" wäre falsch.
    #expect(KitchenLinkTableLabel.headline("Terrasse 1") == "Terrasse 1")
    #expect(KitchenLinkTableLabel.headline("") == "")
}

@Test func gastURLVerwendetDenselbenParameterWieDasGastWeb() {
    let text = KitchenLinkTableGuestURL.text(
        host: "kitchenlink.luneq.eu",
        venueSlug: "alte-muehle",
        token: "abc123"
    )
    // Muss zu `TABLE_QUERY_PARAM` in guest-web/src/lib/table-context.ts passen.
    #expect(text == "https://kitchenlink.luneq.eu/alte-muehle/menu?tisch=abc123")
    #expect(KitchenLinkTableGuestURL.url(
        host: "kitchenlink.luneq.eu",
        venueSlug: "alte-muehle",
        token: "abc123"
    ) != nil)
}

@Test func gastURLKodiertSonderzeichenImToken() {
    let text = KitchenLinkTableGuestURL.text(
        host: "example.test",
        venueSlug: "v",
        token: "a b&c=d"
    )
    #expect(!text.contains("a b"))
    #expect(!text.contains("&c="))
    #expect(URL(string: text) != nil)
}

// MARK: - Zeilen-Mapping

@Test func wireTableWaehltDasAktiveTischTokenAus() {
    let row = KitchenLinkWireTable(
        id: "t1",
        label: "3",
        area: "Gastraum",
        sortOrder: 30,
        active: true,
        qrTokens: [
            .init(token: "alt", active: false, mode: "table"),
            .init(token: "fremd", active: true, mode: "venue_shared"),
            .init(token: "gueltig", active: true, mode: "table")
        ]
    )
    #expect(row.table.token == "gueltig")
    #expect(row.table.headline == "Tisch 3")
}

@Test func wireTableOhneTokenBleibtOhneQRCode() {
    let row = KitchenLinkWireTable(
        id: "t2",
        label: "Theke",
        area: nil,
        sortOrder: nil,
        active: true,
        qrTokens: []
    )
    #expect(row.table.token == nil)
    #expect(row.table.area.isEmpty)
    #expect(row.table.sortOrder == 0)
    #expect(row.table.areaOrDefault == "Ohne Bereich")
}

// MARK: - Tisch an der Bestellung

@Test func cloudBestellungTraegtDenTischInDieBetreiberzeile() throws {
    let json = """
    [{
      "id": "11111111-2222-3333-4444-555555555555",
      "created_at": "2026-07-30T10:15:00.123456+00:00",
      "status": "pending",
      "total_cents": 690,
      "currency": "EUR",
      "service_mode": "dine_in",
      "customer_note": "",
      "source_device": "guest_web",
      "table_id": "aaaa-bbbb",
      "tables": { "label": "3", "area": "Gastraum" },
      "order_items": [
        { "id": "i1", "name": "Kürbissuppe", "quantity": 1, "unit_price_cents": 690, "kind": "food" }
      ]
    }]
    """
    let rows = try JSONDecoder().decode([KitchenLinkCloudWireOrder].self, from: Data(json.utf8))
    let order = try #require(rows.first?.liveOrder(venueID: "v1", venueName: "Alte Mühle"))

    #expect(order.tableID == "aaaa-bbbb")
    #expect(order.tableLabel == "3")
    #expect(order.operatorContextLine.contains("Tisch 3"))
}

@Test func cloudBestellungOhneTischBleibtWieBisher() throws {
    let json = """
    [{
      "id": "11111111-2222-3333-4444-555555555555",
      "created_at": "2026-07-30T10:15:00.123456+00:00",
      "status": "pending",
      "total_cents": 690,
      "currency": "EUR",
      "service_mode": "pickup",
      "customer_note": "",
      "source_device": "guest_web",
      "table_id": null,
      "tables": null,
      "order_items": []
    }]
    """
    let rows = try JSONDecoder().decode([KitchenLinkCloudWireOrder].self, from: Data(json.utf8))
    let order = try #require(rows.first?.liveOrder(venueID: "v1", venueName: "Alte Mühle"))

    #expect(order.tableID == nil)
    #expect(order.tableLabel == nil)
    #expect(!order.operatorContextLine.contains("Tisch"))
}

@Test func barTischErzeugtKeinTischTheke() {
    let order = LiveOrderMessage(
        id: "o1",
        createdAt: Date(),
        sourceDevice: "guest_web",
        venueID: "v1",
        venueName: nil,
        serviceMode: .bar,
        tableID: "t9",
        tableLabel: "Theke",
        customerNote: "",
        items: [],
        totalCents: 0,
        status: .pending
    )
    #expect(order.operatorContextLine.contains("Theke"))
    #expect(!order.operatorContextLine.contains("Tisch Theke"))
}

// MARK: - Modell

@MainActor
@Test func ohneSitzungFragtDasModellNachAnmeldung() async {
    let spy = TablesSpy()
    let model = makeModel(spy: spy, store: makeStore())

    await model.load()

    #expect(model.phase == .needsSignIn)
    #expect(await spy.loadCalls == 0)
}

@MainActor
@Test func mitSitzungLaedtUndGruppiertNachBereich() async {
    let store = makeStore()
    store.save(session: session(access: "at1"))
    let spy = TablesSpy(tables: [
        table(id: "t1", label: "1", area: "Gastraum", sortOrder: 10, token: "tok1"),
        table(id: "t3", label: "Theke", area: "Bar", sortOrder: 60, token: "tok3"),
        table(id: "t2", label: "2", area: "Gastraum", sortOrder: 20, token: "tok2")
    ])
    let model = makeModel(spy: spy, store: store)

    await model.load()

    #expect(model.phase == .ready)
    #expect(model.groupedTables.map(\.area) == ["Gastraum", "Bar"])
    #expect(model.groupedTables.first?.tables.map(\.label) == ["1", "2"])
    #expect(await spy.lastLoadAccessToken == "at1")
}

@MainActor
@Test func gastURLDesTischesEnthaeltSeinToken() async {
    let store = makeStore()
    store.save(session: session(access: "at1"))
    let model = makeModel(spy: TablesSpy(), store: store)

    let text = model.guestURLText(for: table(token: "tok-3"))
    #expect(text?.hasSuffix("/alte-muehle/menu?tisch=tok-3") == true)
    #expect(model.guestURLText(for: table(token: nil)) == nil)
    #expect(model.guestURL(for: table(token: nil)) == nil)
}

@MainActor
@Test func neuerTischReihtSichHintenEinUndLaedtNeu() async {
    let store = makeStore()
    store.save(session: session(access: "at1"))
    let spy = TablesSpy(tables: [table(id: "t1", label: "1", sortOrder: 10, token: "tok1")])
    let model = makeModel(spy: spy, store: store)
    await model.load()

    await model.addTable(label: "  Terrasse 1 ", area: " Terrasse ")

    let calls = await spy.upsertCalls
    #expect(calls.count == 1)
    #expect(calls.first?.label == "Terrasse 1")
    #expect(calls.first?.area == "Terrasse")
    #expect(calls.first?.sortOrder == 20)
    #expect(calls.first?.tableID == nil)
    // Die Liste kommt nach jeder Änderung frisch vom Server, nicht aus der App.
    #expect(await spy.loadCalls == 2)
    #expect(model.tables.count == 2)
}

@MainActor
@Test func tischOhneBezeichnungWirdNichtGesendet() async {
    let store = makeStore()
    store.save(session: session(access: "at1"))
    let spy = TablesSpy()
    let model = makeModel(spy: spy, store: store)
    await model.load()

    await model.addTable(label: "   ", area: "Gastraum")

    #expect(await spy.upsertCalls.isEmpty)
    #expect(model.notice == "Der Tisch braucht eine Bezeichnung.")
}

@MainActor
@Test func umbenennenSchicktDieTischID() async {
    let store = makeStore()
    store.save(session: session(access: "at1"))
    let spy = TablesSpy(tables: [table(id: "t1", label: "1", token: "tok1")])
    let model = makeModel(spy: spy, store: store)
    await model.load()

    await model.update(table: table(id: "t1", label: "1"), label: "1a", area: "Gastraum", active: false)

    let call = await spy.upsertCalls.first
    #expect(call?.tableID == "t1")
    #expect(call?.label == "1a")
    #expect(call?.active == false)
}

@MainActor
@Test func abgelaufeneSitzungWirdGenauEinmalErneuertUndDieAktionWiederholt() async {
    let store = makeStore()
    store.save(session: session(access: "at1", refresh: "rt1"))
    let spy = TablesSpy()
    await spy.setRefreshResult(session(access: "at2", refresh: "rt2"))
    await spy.setFailFirstUpsertUnauthorized(true)
    let model = makeModel(spy: spy, store: store)
    await model.load()

    await model.addTable(label: "7", area: "Gastraum")

    #expect(await spy.refreshCalls == 1)
    #expect(await spy.upsertCalls.count == 2)
    #expect(store.loadSession()?.accessToken == "at2")
    #expect(model.notice == "7 angelegt")
}

@MainActor
@Test func totesRefreshTokenVerwirftDieSitzung() async {
    let store = makeStore()
    store.save(session: session(access: "at1", refresh: "rt1"))
    let spy = TablesSpy()
    await spy.setFailFirstUpsertUnauthorized(true)
    await spy.setRefreshError(.unauthorized)
    let model = makeModel(spy: spy, store: store)
    await model.load()

    await model.addTable(label: "7", area: "Gastraum")

    #expect(store.loadSession() == nil)
    #expect(model.phase == .needsSignIn)
    #expect(model.notice?.contains("abgelaufen") == true)
}

@MainActor
@Test func loeschenMitBestellungenMeldetDenServerfehlerUnveraendert() async {
    let store = makeStore()
    store.save(session: session(access: "at1"))
    let spy = TablesSpy(tables: [table(id: "t1")])
    await spy.setUpsertError(nil)
    let model = makeModel(spy: spy, store: store)
    await model.load()

    // Der Server entscheidet, nicht die App: die RPC lehnt Tische mit
    // Bestellungen ab (`table_in_use`), die App zeigt genau das.
    await model.delete(table: table(id: "t1"))
    #expect(await spy.deleteCalls == ["t1"])
}

@MainActor
@Test func anmeldungLaedtDieTischeDirektNach() async {
    let store = makeStore()
    let spy = TablesSpy(tables: [table()])
    await spy.setSignInResult(session(access: "frisch"))
    let model = makeModel(spy: spy, store: store)

    await model.signIn(email: " betreiber@restaurant.de ", password: "geheim")

    #expect(await spy.signInCalls == 1)
    #expect(model.phase == .ready)
    #expect(model.tables.count == 1)
    #expect(store.loadSession()?.accessToken == "frisch")
}

@MainActor
@Test func leereZugangsdatenErzeugenKeinenNetzwerkaufruf() async {
    let spy = TablesSpy()
    let model = makeModel(spy: spy, store: makeStore())

    await model.signIn(email: "", password: "")

    #expect(await spy.signInCalls == 0)
    #expect(model.phase == .failed("E-Mail und Passwort sind erforderlich."))
}
