import Foundation
import Testing
@testable import kitchenlink

/// KL-PAY-001: Rechnung, Trinkgeld und simulierte Zahlung.
///
/// Geprüft wird die Seite, die im Gerät entschieden wird: Auswahl, Betrag der
/// Auswahl, Trinkgeld, Reihenfolge Anbieter → Buchung, und dass ein
/// wiederholter Versuch denselben Idempotenz-Schlüssel behält.
///
/// Was hier NICHT bewiesen wird: die Buchung selbst. Dass eine Position nicht
/// zweimal kassiert werden kann, entscheidet die Datenbank —
/// `scripts/tests/payments.sql` prüft das gegen echtes PostgreSQL.

// MARK: - Helfer

private func session() -> KitchenLinkCloudSession {
    KitchenLinkCloudSession(
        accessToken: "at",
        refreshToken: "rt",
        userID: "user-1",
        expiresAt: .distantFuture
    )
}

private func makeStore(withSession: Bool = true) -> KitchenLinkCloudCredentialStore {
    let defaults = UserDefaults(suiteName: "pay-\(UUID().uuidString)")!
    let store = KitchenLinkCloudCredentialStore(defaults: defaults, secrets: InMemorySecretStore())
    if withSession { store.save(session: session()) }
    return store
}

private func table() -> KitchenLinkVenueTable {
    KitchenLinkVenueTable(
        id: "t1", label: "3", area: "Gastraum", sortOrder: 10, active: true, token: "tok"
    )
}

private func item(
    id: String,
    name: String,
    quantity: Int = 1,
    unitPriceCents: Int,
    paid: Bool = false
) -> KitchenLinkCheckItem {
    KitchenLinkCheckItem(
        id: id,
        name: name,
        quantity: quantity,
        unitPriceCents: unitPriceCents,
        lineTotalCents: quantity * unitPriceCents,
        paid: paid
    )
}

private func check(
    items: [KitchenLinkCheckItem],
    paidCents: Int = 0,
    tipCents: Int = 0
) -> KitchenLinkCheck {
    let total = items.reduce(0) { $0 + $1.lineTotalCents }
    return KitchenLinkCheck(
        tableSessionID: "session-1",
        totalCents: total,
        paidCents: paidCents,
        tipCents: tipCents,
        openCents: total - paidCents,
        items: items
    )
}

private actor CheckSpy: KitchenLinkCheckTransport, KitchenLinkCloudAuthenticating {
    struct PaymentCall: Equatable {
        let tableSessionID: String
        let method: String
        let idempotencyKey: String
        let tipCents: Int
        let orderItemIDs: [String]
        let amountCents: Int?
        let providerReference: String?
    }

    var checkResult: KitchenLinkCheck
    var paymentError: Error?
    var failFirstPaymentUnauthorized = false
    private(set) var paymentCalls: [PaymentCall] = []
    private(set) var refundCalls: [(paymentID: String, reason: String, token: String?)] = []
    private(set) var loadCalls = 0
    private(set) var refreshCalls = 0

    init(checkResult: KitchenLinkCheck) {
        self.checkResult = checkResult
    }

    func setCheckResult(_ value: KitchenLinkCheck) { checkResult = value }
    func setPaymentError(_ value: Error?) { paymentError = value }
    func setFailFirstPaymentUnauthorized(_ value: Bool) { failFirstPaymentUnauthorized = value }

    func signIn(
        config: KitchenLinkCloudConfig, email: String, password: String
    ) async throws -> KitchenLinkCloudSession { session() }

    func refresh(
        config: KitchenLinkCloudConfig, refreshToken: String
    ) async throws -> KitchenLinkCloudSession {
        refreshCalls += 1
        return session()
    }

    func loadCheck(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        tableID: String
    ) async throws -> KitchenLinkCheck {
        loadCalls += 1
        return checkResult
    }

    func recordPayment(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        tableSessionID: String,
        method: KitchenLinkPaymentMethod,
        idempotencyKey: String,
        tipCents: Int,
        orderItemIDs: [String],
        amountCents: Int?,
        providerReference: String?
    ) async throws -> KitchenLinkPaymentReceipt {
        paymentCalls.append(
            PaymentCall(
                tableSessionID: tableSessionID,
                method: method.rawValue,
                idempotencyKey: idempotencyKey,
                tipCents: tipCents,
                orderItemIDs: orderItemIDs.sorted(),
                amountCents: amountCents,
                providerReference: providerReference
            )
        )
        if failFirstPaymentUnauthorized && paymentCalls.count == 1 {
            throw KitchenLinkCloudServiceError.unauthorized
        }
        if let paymentError { throw paymentError }
        return KitchenLinkPaymentReceipt(
            paymentID: "payment-1",
            amountCents: amountCents ?? 0,
            tipCents: tipCents,
            providerReference: providerReference ?? "sandbox-db",
            openCents: 0,
            sessionClosed: true,
            replayed: false
        )
    }

    func refundPayment(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        paymentID: String,
        reason: String,
        overrideToken: String?
    ) async throws {
        refundCalls.append((paymentID, reason, overrideToken))
    }
}

/// KL-ROLE-002: eine Rolle und ein PIN-Zustand nach Wunsch.
private actor RoleAndPinSpy: KitchenLinkPermissionTransport, KitchenLinkManagerPinTransport {
    let role: KitchenLinkMyRole
    let status: KitchenLinkManagerPinStatus
    let result: KitchenLinkManagerPinAuthorization
    private(set) var authorizeCalls: [(permission: String, pin: String)] = []

    init(
        role: KitchenLinkMyRole,
        status: KitchenLinkManagerPinStatus = KitchenLinkManagerPinStatus(
            hasPin: false, updatedAt: nil, authorizers: 1
        ),
        result: KitchenLinkManagerPinAuthorization = .granted(
            KitchenLinkManagerOverride(
                token: "tok-1", permission: "payments.refund",
                expiresAt: nil, grantedByEmail: "chefin@restaurant.de"
            )
        )
    ) {
        self.role = role
        self.status = status
        self.result = result
    }

    func loadMyRole(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> KitchenLinkMyRole { role }

    func pinStatus(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> KitchenLinkManagerPinStatus { status }

    func setPin(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        pin: String
    ) async throws {}

    func clearPin(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        userID: String?
    ) async throws {}

    func authorize(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        permission: KitchenLinkVenuePermission,
        pin: String,
        note: String?,
        context: [String: String]
    ) async throws -> KitchenLinkManagerPinAuthorization {
        authorizeCalls.append((permission.rawValue, pin))
        return result
    }

    func recentOverrides(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        limit: Int
    ) async throws -> [KitchenLinkManagerOverrideRecord] { [] }
}

private let ownerRole = KitchenLinkMyRole(
    roleKey: "owner", roleName: "Inhaber",
    permissions: ["shift.open", "shift.close", "cash.movement",
                  "payments.refund", "staff.manage"]
)

private let serviceRole = KitchenLinkMyRole(
    roleKey: "service", roleName: "Service", permissions: []
)

private struct DecliningProvider: KitchenLinkPaymentProviding {
    func authorize(
        amountCents: Int, tipCents: Int, method: KitchenLinkPaymentMethod
    ) async throws -> KitchenLinkPaymentAuthorization {
        throw KitchenLinkPaymentProviderError.declined("Karte abgelehnt")
    }
}

private actor CountingProvider: KitchenLinkPaymentProviding {
    private(set) var calls = 0
    func authorize(
        amountCents: Int, tipCents: Int, method: KitchenLinkPaymentMethod
    ) async throws -> KitchenLinkPaymentAuthorization {
        calls += 1
        return KitchenLinkPaymentAuthorization(reference: "sandbox-terminal-1", simulated: true)
    }
}

@MainActor
private func makeModel(
    spy: CheckSpy,
    provider: KitchenLinkPaymentProviding = KitchenLinkSandboxPaymentProvider(),
    store: KitchenLinkCloudCredentialStore? = nil,
    roles: RoleAndPinSpy = RoleAndPinSpy(role: ownerRole)
) -> KitchenLinkCheckModel {
    KitchenLinkCheckModel(
        table: table(),
        config: .sandboxDefault,
        auth: spy,
        transport: spy,
        permissions: roles,
        pin: roles,
        provider: provider,
        store: store ?? makeStore()
    )
}

// MARK: - Rechnung lesen

@Test func rechnungDekodiertPositionenUndSummen() throws {
    let json = """
    {
      "table_session_id": "s1",
      "total_cents": 2070,
      "paid_cents": 690,
      "tip_cents": 100,
      "open_cents": 1380,
      "items": [
        {"order_item_id":"i1","name":"Kürbissuppe","quantity":2,
         "unit_price_cents":690,"line_total_cents":1380,"paid":false},
        {"order_item_id":"i2","name":"Suppe","quantity":1,
         "unit_price_cents":690,"line_total_cents":690,"paid":true},
        {"kaputt":true}
      ]
    }
    """
    let decoded = try KitchenLinkCheck.decode(Data(json.utf8))

    #expect(decoded.tableSessionID == "s1")
    #expect(decoded.openCents == 1380)
    #expect(decoded.tipCents == 100)
    // Die unlesbare Zeile wird verworfen, nicht geraten.
    #expect(decoded.items.count == 2)
    #expect(decoded.items.first?.lineTotalCents == 1380)
    #expect(decoded.isSettled == false)
}

@Test func leereRechnungIstKeinFehler() throws {
    let json = """
    {"table_session_id": null, "total_cents": 0, "paid_cents": 0,
     "tip_cents": 0, "open_cents": 0, "items": []}
    """
    let decoded = try KitchenLinkCheck.decode(Data(json.utf8))
    #expect(decoded.tableSessionID == nil)
    #expect(decoded.items.isEmpty)
    #expect(decoded.hasOpenItems == false)
}

// MARK: - Auswahl und Betrag

@MainActor
@Test func ohneAuswahlWirdDerGanzeOffeneBetragKassiert() async {
    let spy = CheckSpy(checkResult: check(items: [
        item(id: "i1", name: "Suppe", unitPriceCents: 690),
        item(id: "i2", name: "Schnitzel", unitPriceCents: 2180)
    ]))
    let model = makeModel(spy: spy)
    await model.load()

    #expect(model.selectionCents == 2870)
    #expect(model.isPartialPayment == false)
    #expect(model.canPay)
}

@MainActor
@Test func auswahlEinzelnerPositionenIstGetrenntZahlen() async {
    let spy = CheckSpy(checkResult: check(items: [
        item(id: "i1", name: "Suppe", unitPriceCents: 690),
        item(id: "i2", name: "Schnitzel", unitPriceCents: 2180)
    ]))
    let model = makeModel(spy: spy)
    await model.load()

    model.toggle(model.check.items[0])
    #expect(model.selectionCents == 690)
    #expect(model.isPartialPayment)

    model.toggle(model.check.items[1])
    #expect(model.selectionCents == 2870)
    // Alles ausgewählt ist keine Teilzahlung mehr.
    #expect(model.isPartialPayment == false)

    model.toggle(model.check.items[0])
    #expect(model.selectionCents == 2180)
}

@MainActor
@Test func bereitsBezahltePositionenSindNichtWaehlbar() async {
    let spy = CheckSpy(checkResult: check(
        items: [
            item(id: "i1", name: "Suppe", unitPriceCents: 690, paid: true),
            item(id: "i2", name: "Schnitzel", unitPriceCents: 2180)
        ],
        paidCents: 690
    ))
    let model = makeModel(spy: spy)
    await model.load()

    model.toggle(model.check.items[0])

    #expect(model.selectedItemIDs.isEmpty)
    #expect(model.openItems.map(\.id) == ["i2"])
    #expect(model.paidItems.map(\.id) == ["i1"])
    #expect(model.selectionCents == 2180)
}

@MainActor
@Test func trinkgeldKommtObenDrauf() async {
    let spy = CheckSpy(checkResult: check(items: [
        item(id: "i1", name: "Suppe", unitPriceCents: 1000)
    ]))
    let model = makeModel(spy: spy)
    await model.load()
    model.tipCents = 150

    #expect(model.selectionCents == 1000)
    #expect(model.payableCents == 1150)

    await model.pay()

    let call = await spy.paymentCalls.first
    // Das Trinkgeld geht getrennt an die Datenbank — es ist kein Umsatz.
    #expect(call?.amountCents == 1000)
    #expect(call?.tipCents == 150)
}

// MARK: - Buchen

@MainActor
@Test func auswahlWirdAlsPositionslisteGebucht() async {
    let spy = CheckSpy(checkResult: check(items: [
        item(id: "i1", name: "Suppe", unitPriceCents: 690),
        item(id: "i2", name: "Schnitzel", unitPriceCents: 2180)
    ]))
    let model = makeModel(spy: spy)
    await model.load()
    model.toggle(model.check.items[0])

    await model.pay()

    let call = await spy.paymentCalls.first
    #expect(call?.orderItemIDs == ["i1"])
    #expect(call?.amountCents == 690)
    #expect(call?.tableSessionID == "session-1")
    // Nach der Buchung ist die Auswahl leer und der Beleg da.
    #expect(model.selectedItemIDs.isEmpty)
    #expect(model.lastReceipt?.paymentID == "payment-1")
    #expect(model.tipCents == 0)
}

@MainActor
@Test func barzahlungFragtKeinenAnbieter() async {
    let spy = CheckSpy(checkResult: check(items: [item(id: "i1", name: "Suppe", unitPriceCents: 690)]))
    let provider = CountingProvider()
    let model = makeModel(spy: spy, provider: provider)
    await model.load()
    model.method = .cash

    await model.pay()

    #expect(await provider.calls == 0)
    #expect(await spy.paymentCalls.first?.providerReference == nil)
}

@MainActor
@Test func karteLaeuftUeberDenAnbieterUndTraegtDessenReferenz() async {
    let spy = CheckSpy(checkResult: check(items: [item(id: "i1", name: "Suppe", unitPriceCents: 690)]))
    let provider = CountingProvider()
    let model = makeModel(spy: spy, provider: provider)
    await model.load()
    model.method = .card

    await model.pay()

    #expect(await provider.calls == 1)
    #expect(await spy.paymentCalls.first?.providerReference == "sandbox-terminal-1")
}

@MainActor
@Test func abgelehnteAutorisierungErzeugtKeineBuchung() async {
    let spy = CheckSpy(checkResult: check(items: [item(id: "i1", name: "Suppe", unitPriceCents: 690)]))
    let model = makeModel(spy: spy, provider: DecliningProvider())
    await model.load()
    model.method = .tapToPay

    await model.pay()

    #expect(await spy.paymentCalls.isEmpty, "Ohne Autorisierung darf nichts gebucht werden")
    #expect(model.notice?.contains("abgelehnt") == true)
    #expect(model.lastReceipt == nil)
}

@MainActor
@Test func abgelaufeneSitzungBehaeltDenIdempotenzSchluessel() async {
    let spy = CheckSpy(checkResult: check(items: [item(id: "i1", name: "Suppe", unitPriceCents: 690)]))
    await spy.setFailFirstPaymentUnauthorized(true)
    let model = makeModel(spy: spy)
    await model.load()

    await model.pay()

    let calls = await spy.paymentCalls
    #expect(calls.count == 2)
    // Entscheidend: derselbe Schlüssel. Sonst wäre der zweite Versuch eine
    // zweite Zahlung, falls der erste die Datenbank doch erreicht hat.
    #expect(calls[0].idempotencyKey == calls[1].idempotencyKey)
    #expect(await spy.refreshCalls == 1)
}

@MainActor
@Test func geaenderteAuswahlIstEinNeuerVorgang() async {
    let spy = CheckSpy(checkResult: check(items: [
        item(id: "i1", name: "Suppe", unitPriceCents: 690),
        item(id: "i2", name: "Schnitzel", unitPriceCents: 2180)
    ]))
    await spy.setPaymentError(KitchenLinkCloudServiceError.server(status: 500, message: "Netz weg"))
    let model = makeModel(spy: spy)
    await model.load()

    model.toggle(model.check.items[0])
    await model.pay()
    let firstKey = await spy.paymentCalls.first?.idempotencyKey

    // Wiederholung desselben Vorgangs: gleicher Schlüssel.
    await model.pay()
    #expect(await spy.paymentCalls[1].idempotencyKey == firstKey)

    // Andere Auswahl: anderer Vorgang.
    model.toggle(model.check.items[1])
    await model.pay()
    #expect(await spy.paymentCalls[2].idempotencyKey != firstKey)
}

@MainActor
@Test func ohneAnmeldungWirdNichtKassiert() async {
    let spy = CheckSpy(checkResult: check(items: [item(id: "i1", name: "Suppe", unitPriceCents: 690)]))
    let model = makeModel(spy: spy, store: makeStore(withSession: false))

    await model.load()

    #expect(model.phase == .needsSignIn)
    #expect(await spy.loadCalls == 0)
}

@MainActor
@Test func stornoGehtMitGrundAnDieDatenbank() async {
    let spy = CheckSpy(checkResult: check(items: [item(id: "i1", name: "Suppe", unitPriceCents: 690)]))
    let model = makeModel(spy: spy)
    await model.load()

    await model.refund(paymentID: "payment-1", reason: "Falsch kassiert")

    let call = await spy.refundCalls.first
    #expect(call?.paymentID == "payment-1")
    #expect(call?.reason == "Falsch kassiert")
    #expect(model.lastReceipt == nil)
}

// MARK: - Sandbox-Provider

@Test func sandboxProviderLiefertEineSimulierteReferenz() async throws {
    let provider = KitchenLinkSandboxPaymentProvider()
    let authorization = try await provider.authorize(
        amountCents: 1000, tipCents: 0, method: .card
    )
    #expect(authorization.simulated)
    #expect(authorization.reference.hasPrefix("sandbox-"))
}

@Test func sandboxProviderLehntEinenNullbetragAb() async {
    let provider = KitchenLinkSandboxPaymentProvider()
    await #expect(throws: KitchenLinkPaymentProviderError.self) {
        _ = try await provider.authorize(amountCents: 0, tipCents: 0, method: .card)
    }
}

@Test func barUndGutscheinBrauchenKeinenAnbieter() {
    #expect(KitchenLinkPaymentMethod.cash.requiresProvider == false)
    #expect(KitchenLinkPaymentMethod.voucher.requiresProvider == false)
    #expect(KitchenLinkPaymentMethod.card.requiresProvider)
    #expect(KitchenLinkPaymentMethod.tapToPay.requiresProvider)
    #expect(KitchenLinkPaymentMethod.tapToPay.rawValue == "tap_to_pay")
}

// MARK: - Storno und Freigabe (KL-ROLE-002)

@MainActor
@Test func ohneRechtUndOhneFreigabeWirdDerStornoGarNichtErstVersucht() async {
    let spy = CheckSpy(checkResult: check(items: [
        item(id: "i1", name: "Suppe", unitPriceCents: 690)
    ]))
    let model = makeModel(spy: spy, roles: RoleAndPinSpy(role: serviceRole))
    await model.load()

    #expect(model.canRefund == false)
    #expect(model.refundGate.allowsAuthorization)

    await model.refund(paymentID: "payment-1", reason: "Falsch kassiert")

    // Die Datenbank würde abweisen; der Weg dorthin wäre nur ein Umweg über
    // einen Fehler, den niemand versteht.
    #expect(await spy.refundCalls.isEmpty)
    #expect(model.notice?.contains("Service") == true)
}

@MainActor
@Test func mitFreigabeGehtDerStornoDurchUndDerTokenWirdMitgeschickt() async {
    let spy = CheckSpy(checkResult: check(items: [
        item(id: "i1", name: "Suppe", unitPriceCents: 690)
    ]))
    let model = makeModel(spy: spy, roles: RoleAndPinSpy(role: serviceRole))
    await model.load()

    await model.refund(
        paymentID: "payment-1", reason: "Falsch kassiert", overrideToken: "tok-1"
    )

    let call = await spy.refundCalls.first
    #expect(call?.token == "tok-1")
    // Der Beleg sagt, dass es eine Ausnahme war — und dass sie festgehalten ist.
    #expect(model.notice?.contains("protokolliert") == true)
}

@MainActor
@Test func werStornierenDarfSchicktKeinenToken() async {
    let spy = CheckSpy(checkResult: check(items: [
        item(id: "i1", name: "Suppe", unitPriceCents: 690)
    ]))
    let model = makeModel(spy: spy)
    await model.load()

    #expect(model.canRefund)
    await model.refund(paymentID: "payment-1", reason: "Falsch kassiert")

    #expect(await spy.refundCalls.first?.token == nil)
}

@MainActor
@Test func ohneLesbareRolleEntscheidetWieFrueherDieDatenbank() async {
    // Eine Instanz ohne die Rechte-Migration darf nicht dazu führen, dass die
    // App eine Sperre erfindet, die es dort gar nicht gibt.
    let spy = CheckSpy(checkResult: check(items: [
        item(id: "i1", name: "Suppe", unitPriceCents: 690)
    ]))
    let model = KitchenLinkCheckModel(
        table: table(),
        config: .sandboxDefault,
        auth: spy,
        transport: spy,
        permissions: FailingRoleSpy(),
        pin: FailingRoleSpy(),
        store: makeStore()
    )
    await model.load()

    #expect(model.canRefund)
    await model.refund(paymentID: "payment-1", reason: "Falsch kassiert")
    #expect(await spy.refundCalls.count == 1)
}

private actor FailingRoleSpy: KitchenLinkPermissionTransport, KitchenLinkManagerPinTransport {
    func loadMyRole(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> KitchenLinkMyRole {
        throw KitchenLinkCloudServiceError.server(status: 404, message: "does not exist")
    }

    func pinStatus(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> KitchenLinkManagerPinStatus {
        throw KitchenLinkCloudServiceError.server(status: 404, message: "does not exist")
    }

    func setPin(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        pin: String
    ) async throws {}

    func clearPin(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        userID: String?
    ) async throws {}

    func authorize(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        permission: KitchenLinkVenuePermission,
        pin: String,
        note: String?,
        context: [String: String]
    ) async throws -> KitchenLinkManagerPinAuthorization { .refused(.notNeeded) }

    func recentOverrides(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        limit: Int
    ) async throws -> [KitchenLinkManagerOverrideRecord] { [] }
}
