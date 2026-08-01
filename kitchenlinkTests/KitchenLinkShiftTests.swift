import Foundation
import Testing
@testable import kitchenlink

/// KL-SHIFT-001: Betriebsschicht und Kassenabschluss.
///
/// Zwei Dinge sind hier teuer, wenn sie falsch sind: die Euro-Eingabe (ein
/// falsch gelesener Betrag geht direkt in den Abschluss) und die Frage, wer
/// den erwarteten Bargeldbestand bestimmt — die Datenbank, nie das Gerät.

private func session() -> KitchenLinkCloudSession {
    KitchenLinkCloudSession(
        accessToken: "at", refreshToken: "rt", userID: "user-1", expiresAt: .distantFuture
    )
}

private func makeStore(withSession: Bool = true) -> KitchenLinkCloudCredentialStore {
    let defaults = UserDefaults(suiteName: "shift-\(UUID().uuidString)")!
    let store = KitchenLinkCloudCredentialStore(defaults: defaults, secrets: InMemorySecretStore())
    if withSession { store.save(session: session()) }
    return store
}

/// Rechte des Testzugangs. Standardmäßig Inhaber — die Schicht-Tests prüfen
/// die Kasse, nicht die Rollen; das tut `KitchenLinkTeamTests`.
private actor RoleSpy: KitchenLinkPermissionTransport {
    private let role: KitchenLinkMyRole

    init(_ permissions: Set<String> = [
        "shift.open", "shift.close", "cash.movement", "payments.refund", "staff.manage"
    ]) {
        self.role = KitchenLinkMyRole(
            roleKey: "owner", roleName: "Inhaber", permissions: permissions
        )
    }

    func loadMyRole(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> KitchenLinkMyRole { role }
}

/// KL-ROLE-002: der PIN-Zustand des Lokals. Standardmäßig hat jemand eine PIN
/// hinterlegt — sonst gäbe es den Weg über die Freigabe gar nicht.
private actor PinSpy: KitchenLinkManagerPinTransport {
    private let status: KitchenLinkManagerPinStatus
    private let result: KitchenLinkManagerPinAuthorization

    init(
        authorizers: Int = 1,
        result: KitchenLinkManagerPinAuthorization = .granted(
            KitchenLinkManagerOverride(
                token: "tok-1", permission: "shift.close",
                expiresAt: nil, grantedByEmail: "chefin@restaurant.de"
            )
        )
    ) {
        self.status = KitchenLinkManagerPinStatus(
            hasPin: false, updatedAt: nil, authorizers: authorizers
        )
        self.result = result
    }

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
    ) async throws -> KitchenLinkManagerPinAuthorization { result }

    func recentOverrides(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        limit: Int
    ) async throws -> [KitchenLinkManagerOverrideRecord] { [] }
}

private actor ShiftSpy: KitchenLinkShiftTransport {
    var report: KitchenLinkShiftReport
    var history: [KitchenLinkShift] = []
    var closeResult: KitchenLinkShiftClose?
    var openError: Error?

    private(set) var openCalls: [(cents: Int, key: String, token: String?)] = []
    private(set) var movementCalls: [(kind: KitchenLinkCashMovementKind, cents: Int, reason: String, key: String, token: String?)] = []
    private(set) var closeCalls: [(cents: Int, note: String, token: String?)] = []

    init(report: KitchenLinkShiftReport = .none) {
        self.report = report
    }

    func setReport(_ value: KitchenLinkShiftReport) { report = value }
    func setCloseResult(_ value: KitchenLinkShiftClose?) { closeResult = value }
    func setOpenError(_ value: Error?) { openError = value }

    func openShift(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        openingCashCents: Int,
        idempotencyKey: String,
        overrideToken: String?
    ) async throws {
        openCalls.append((openingCashCents, idempotencyKey, overrideToken))
        if let openError { throw openError }
    }

    func loadReport(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        shiftID: String?
    ) async throws -> KitchenLinkShiftReport { report }

    func recordCashMovement(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        kind: KitchenLinkCashMovementKind,
        amountCents: Int,
        reason: String,
        idempotencyKey: String,
        overrideToken: String?
    ) async throws {
        movementCalls.append((kind, amountCents, reason, idempotencyKey, overrideToken))
    }

    func closeShift(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        countedCashCents: Int,
        note: String,
        overrideToken: String?
    ) async throws -> KitchenLinkShiftClose {
        closeCalls.append((countedCashCents, note, overrideToken))
        guard let closeResult else { throw KitchenLinkCloudServiceError.invalidResponse }
        return closeResult
    }

    func recentShifts(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        limit: Int
    ) async throws -> [KitchenLinkShift] { history }
}

@MainActor
private func makeModel(
    spy: ShiftSpy,
    store: KitchenLinkCloudCredentialStore? = nil,
    permissions: Set<String> = [
        "shift.open", "shift.close", "cash.movement", "payments.refund", "staff.manage"
    ],
    pin: KitchenLinkManagerPinTransport = PinSpy()
) -> KitchenLinkShiftModel {
    KitchenLinkShiftModel(
        config: .sandboxDefault,
        transport: spy,
        permissions: RoleSpy(permissions),
        pin: pin,
        store: store ?? makeStore()
    )
}

private func openReport(
    expectedCash: Int = 11_050,
    openTableSessions: Int = 0,
    unassignedCash: Int = 0
) -> KitchenLinkShiftReport {
    KitchenLinkShiftReport(
        isOpen: true,
        shift: KitchenLinkShift(
            id: "shift-1", status: "open", openedAt: Date(), closedAt: nil, zNumber: nil,
            openingCashCents: 10_000, countedCashCents: nil, expectedCashCents: nil,
            varianceCents: nil, closeNote: nil
        ),
        totals: KitchenLinkShiftTotals(
            revenueCents: 1_380, tipCents: 160, refundedCents: 0,
            paymentCount: 2, refundCount: 0, cashPaymentsCents: 800,
            payoutCents: 500, expenseCents: 1_250, depositCents: 2_000,
            openingCashCents: 10_000, expectedCashCents: expectedCash,
            byMethod: [
                KitchenLinkShiftMethodTotal(method: "cash", amountCents: 690, tipCents: 110, count: 1),
                KitchenLinkShiftMethodTotal(method: "card", amountCents: 690, tipCents: 50, count: 1)
            ]
        ),
        unassignedCashCents: unassignedCash,
        openTableSessions: openTableSessions
    )
}

// MARK: - Euro-Eingabe

@Test func euroEingabeInDenUeblichenSchreibweisen() {
    #expect(KitchenLinkShiftModel.cents(from: "100") == 10_000)
    #expect(KitchenLinkShiftModel.cents(from: "100,50") == 10_050)
    #expect(KitchenLinkShiftModel.cents(from: "100.50") == 10_050)
    #expect(KitchenLinkShiftModel.cents(from: "0,99") == 99)
    #expect(KitchenLinkShiftModel.cents(from: " 42 ") == 4_200)
    #expect(KitchenLinkShiftModel.cents(from: "€ 12,34") == 1_234)
}

@Test func tausenderpunktNurMitKomma() {
    // „1.234,50" sind 1234,50 EUR — der Punkt trennt Tausender.
    #expect(KitchenLinkShiftModel.cents(from: "1.234,50") == 123_450)
    // „1.50" dagegen sind 1,50 EUR und nicht 150 EUR. Diese Verwechslung wäre
    // im Abschluss ein Fehlbetrag von 148,50 EUR.
    #expect(KitchenLinkShiftModel.cents(from: "1.50") == 150)
}

@Test func eineStelleNachDemKommaIstZehntel() {
    // „5,5" heißt 5,50 EUR, nicht 5,05 EUR.
    #expect(KitchenLinkShiftModel.cents(from: "5,5") == 550)
}

@Test func unlesbareBetraegeErgebenNichts() {
    // Lieber kein Abschluss als ein geratener Betrag.
    #expect(KitchenLinkShiftModel.cents(from: "") == nil)
    #expect(KitchenLinkShiftModel.cents(from: "abc") == nil)
    #expect(KitchenLinkShiftModel.cents(from: "12,345") == nil)
    #expect(KitchenLinkShiftModel.cents(from: "1,2,3") == nil)
    #expect(KitchenLinkShiftModel.cents(from: "-5") == nil)
    #expect(KitchenLinkShiftModel.cents(from: ",50") == nil)
}

// MARK: - Öffnen

@MainActor
@Test func eineGeschlosseneKasseZeigtNurDasOeffnen() async {
    let spy = ShiftSpy(report: .none)
    let model = makeModel(spy: spy)

    await model.load()

    #expect(model.isOpen == false)
    #expect(model.phase == .ready)
}

@MainActor
@Test func derAnfangsbestandKommtAlsCentAn() async {
    let spy = ShiftSpy(report: .none)
    let model = makeModel(spy: spy)
    await model.load()

    model.openingCashText = "150,50"
    await model.openShift()

    let calls = await spy.openCalls
    #expect(calls.count == 1)
    #expect(calls.first?.cents == 15_050)
    // Feld leer für den nächsten Tag.
    #expect(model.openingCashText.isEmpty)
}

@MainActor
@Test func ohneAnfangsbestandWirdNullGeoeffnet() async {
    // Blueprint §8.3: der Anfangsbestand ist optional.
    let spy = ShiftSpy(report: .none)
    let model = makeModel(spy: spy)
    await model.load()

    await model.openShift()

    #expect(await spy.openCalls.first?.cents == 0)
}

@MainActor
@Test func einFehlgeschlagenesOeffnenBehaeltSeinenSchluessel() async {
    // Sonst legt ein zweiter Versuch nach einem Netzwerkfehler eine zweite
    // Schicht an, sobald der erste doch noch durchkam.
    let spy = ShiftSpy(report: .none)
    await spy.setOpenError(KitchenLinkCloudServiceError.invalidResponse)
    let model = makeModel(spy: spy)
    await model.load()

    await model.openShift()
    await model.openShift()

    let calls = await spy.openCalls
    #expect(calls.count == 2)
    #expect(calls[0].key == calls[1].key)
}

@MainActor
@Test func beiOffenerKasseWirdNichtNochmalGeoeffnet() async {
    let spy = ShiftSpy(report: openReport())
    let model = makeModel(spy: spy)
    await model.load()

    await model.openShift()

    #expect(await spy.openCalls.isEmpty)
    #expect(model.notice?.contains("bereits eine Schicht offen") == true)
}

// MARK: - Bewegungen

@MainActor
@Test func eineEntnahmeWirdMitArtUndGrundGebucht() async {
    let spy = ShiftSpy(report: openReport())
    let model = makeModel(spy: spy)
    await model.load()

    model.movementKind = .expense
    model.movementAmountText = "12,50"
    model.movementReason = "Gemüsekiste"
    #expect(model.canBookMovement)

    await model.bookMovement()

    let calls = await spy.movementCalls
    #expect(calls.count == 1)
    #expect(calls.first?.kind == .expense)
    #expect(calls.first?.cents == 1_250)
    #expect(calls.first?.reason == "Gemüsekiste")
    #expect(model.movementAmountText.isEmpty)
    #expect(model.movementReason.isEmpty)
}

@MainActor
@Test func ohneBetragWirdNichtsGebucht() async {
    let spy = ShiftSpy(report: openReport())
    let model = makeModel(spy: spy)
    await model.load()

    model.movementAmountText = "0"
    #expect(model.canBookMovement == false)
    await model.bookMovement()

    #expect(await spy.movementCalls.isEmpty)
}

@MainActor
@Test func beiGeschlossenerKasseGibtEsKeineBewegung() async {
    let spy = ShiftSpy(report: .none)
    let model = makeModel(spy: spy)
    await model.load()

    model.movementAmountText = "10"
    #expect(model.canBookMovement == false)
}

// MARK: - Abschluss

@MainActor
@Test func dieAbweichungIstEineVorschauUndKommtDannVomServer() async {
    let spy = ShiftSpy(report: openReport(expectedCash: 11_050))
    await spy.setCloseResult(
        KitchenLinkShiftClose(
            shiftID: "shift-1", zNumber: 7,
            countedCashCents: 11_000, expectedCashCents: 11_050,
            varianceCents: -50, totals: .empty
        )
    )
    let model = makeModel(spy: spy)
    await model.load()

    model.countedCashText = "110,00"
    // Die App zeigt die Vorschau …
    #expect(model.previewVarianceCents == -50)
    #expect(model.canClose)

    await model.closeShift()

    // … gebucht wird aber, was der Server zurückrechnet.
    #expect(await spy.closeCalls.first?.cents == 11_000)
    #expect(model.lastClose?.varianceCents == -50)
    #expect(model.lastClose?.zNumber == 7)
    #expect(model.lastClose?.isBalanced == false)
    #expect(model.countedCashText.isEmpty)
}

@MainActor
@Test func ohneZaehlungKeinAbschluss() async {
    let spy = ShiftSpy(report: openReport())
    let model = makeModel(spy: spy)
    await model.load()

    #expect(model.canClose == false)
    await model.closeShift()

    #expect(await spy.closeCalls.isEmpty)
    #expect(model.notice?.contains("gezählte Bargeld") == true)
}

@MainActor
@Test func eineStimmendeKasseWirdAlsSolcheGemeldet() async {
    let spy = ShiftSpy(report: openReport())
    await spy.setCloseResult(
        KitchenLinkShiftClose(
            shiftID: "shift-1", zNumber: 1,
            countedCashCents: 11_050, expectedCashCents: 11_050,
            varianceCents: 0, totals: .empty
        )
    )
    let model = makeModel(spy: spy)
    await model.load()

    model.countedCashText = "110,50"
    #expect(model.previewVarianceCents == 0)
    await model.closeShift()

    #expect(model.lastClose?.isBalanced == true)
    #expect(model.notice?.contains("Kasse stimmt") == true)
}

@MainActor
@Test func offeneRechnungenWerdenVorDemAbschlussGenannt() async {
    // Ein Abschluss bei offenen Rechnungen ist erlaubt, aber fast immer ein
    // Versehen: das Geld dieser Tische fehlt dann in der Zaehlung.
    let spy = ShiftSpy(report: openReport(openTableSessions: 3))
    let model = makeModel(spy: spy)
    await model.load()

    #expect(model.hasOpenTablesWarning)
    #expect(model.report.openTableSessions == 3)
}

// MARK: - Bericht

// MARK: - Rechte an der Kasse (KL-ROLE-001)

@MainActor
@Test func ohneRechtBleibtDieKasseLesbarAberUnantastbar() async {
    // Service darf die Kasse sehen — das ist Alltag —, aber nicht abschliessen
    // und kein Bargeld bewegen.
    let spy = ShiftSpy(report: openReport())
    let model = KitchenLinkShiftModel(
        config: .sandboxDefault,
        transport: spy,
        permissions: ServiceRoleSpy(),
        pin: PinSpy(),
        store: makeStore()
    )
    await model.load()

    #expect(model.isOpen)
    #expect(model.totals.expectedCashCents == 11_050)

    model.countedCashText = "110,50"
    #expect(model.canClose == false)
    model.movementAmountText = "5"
    #expect(model.canBookMovement == false)
    #expect(model.canOpenShift == false)

    await model.closeShift()
    #expect(await spy.closeCalls.isEmpty)
}

@MainActor
@Test func dieFehlendeBefugnisWirdErklaertStattNurGesperrt() async {
    let spy = ShiftSpy(report: openReport())
    // Ohne hinterlegte PIN gibt es keinen Weg vorbei — dann nennt der Satz,
    // wer weiterhelfen kann. Mit PIN nennt er stattdessen die Freigabe; das
    // prueft `ohneRechtAberMitPinImLokalBietetDieKasseEineFreigabeAn`.
    let model = KitchenLinkShiftModel(
        config: .sandboxDefault,
        transport: spy,
        permissions: ServiceRoleSpy(),
        pin: PinSpy(authorizers: 0),
        store: makeStore()
    )
    await model.load()

    let note = model.missingPermissionNote(for: .shiftClose)
    // Der Satz nennt die eigene Rolle und wer weiterhelfen kann.
    #expect(note?.contains("Service") == true)
    #expect(note?.contains("Schichtleitung") == true)
    #expect(model.missingPermissionNote(for: .paymentsRefund) != nil)
}

@MainActor
@Test func werDarfBekommtKeinenHinweis() async {
    let spy = ShiftSpy(report: openReport())
    let model = makeModel(spy: spy)
    await model.load()

    #expect(model.missingPermissionNote(for: .shiftClose) == nil)
    #expect(model.missingPermissionNote(for: .cashMovement) == nil)
    #expect(model.canOpenShift)
}

@MainActor
@Test func einZugangOhnePersonalWirdAlsSolcherBenannt() async {
    let spy = ShiftSpy(report: .none)
    let model = KitchenLinkShiftModel(
        config: .sandboxDefault,
        transport: spy,
        permissions: NoRoleSpy(),
        pin: PinSpy(),
        store: makeStore()
    )
    await model.load()

    #expect(model.missingPermissionNote(for: .shiftOpen)?.contains("nicht zum Personal") == true)
}

private actor ServiceRoleSpy: KitchenLinkPermissionTransport {
    func loadMyRole(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> KitchenLinkMyRole {
        KitchenLinkMyRole(roleKey: "service", roleName: "Service", permissions: [])
    }
}

private actor NoRoleSpy: KitchenLinkPermissionTransport {
    func loadMyRole(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> KitchenLinkMyRole { .none }
}

@MainActor
@Test func geldOhneSchichtWirdGenanntStattGeschluckt() async {
    let spy = ShiftSpy(report: openReport(unassignedCash: 690))
    let model = makeModel(spy: spy)
    await model.load()

    #expect(model.report.unassignedCashCents == 690)
}

@MainActor
@Test func ohneAnmeldungWirdNichtsGeladen() async {
    let spy = ShiftSpy(report: openReport())
    let model = makeModel(spy: spy, store: makeStore(withSession: false))

    await model.load()

    #expect(model.phase == .needsSignIn)
    #expect(model.isOpen == false)
}

@Test func dieZahlartenWerdenLesbarBenannt() {
    #expect(KitchenLinkShiftMethodTotal(method: "cash", amountCents: 0, tipCents: 0, count: 0).label == "Bar")
    #expect(KitchenLinkShiftMethodTotal(method: "tap_to_pay", amountCents: 0, tipCents: 0, count: 0).label == "Tap to Pay")
    // Eine unbekannte Zahlart wird durchgereicht statt verschluckt.
    #expect(KitchenLinkShiftMethodTotal(method: "krypto", amountCents: 0, tipCents: 0, count: 0).label == "krypto")
}

// MARK: - Dekodierung

@Test func derBerichtWirdAusDerRpcAntwortGelesen() throws {
    let json = """
    {
      "open": true,
      "shift": {
        "id": "s-1", "status": "open", "opened_at": "2026-07-31T08:00:00+00:00",
        "closed_at": null, "z_number": null, "counted_cash_cents": null,
        "expected_cash_cents": 11050, "variance_cents": null, "close_note": null
      },
      "totals": {
        "revenue_cents": 1380, "tip_cents": 160, "refunded_cents": 0,
        "payment_count": 2, "refund_count": 0, "cash_payments_cents": 800,
        "payout_cents": 500, "expense_cents": 1250, "deposit_cents": 2000,
        "opening_cash_cents": 10000, "expected_cash_cents": 11050,
        "by_method": {
          "cash": {"amount_cents": 690, "tip_cents": 110, "count": 1},
          "card": {"amount_cents": 690, "tip_cents": 50, "count": 1}
        }
      },
      "unassigned_cash_cents": 0,
      "open_table_sessions": 2
    }
    """
    let report = try KitchenLinkShiftReport.decode(Data(json.utf8))

    #expect(report.isOpen)
    #expect(report.shift?.id == "s-1")
    #expect(report.shift?.openedAt != nil)
    #expect(report.totals.expectedCashCents == 11_050)
    #expect(report.totals.byMethod.count == 2)
    #expect(report.openTableSessions == 2)
}

@Test func einBerichtOhneOffeneSchichtIstKeinFehler() throws {
    let report = try KitchenLinkShiftReport.decode(Data(#"{"open": false, "shift": null}"#.utf8))
    #expect(report.isOpen == false)
    #expect(report.shift == nil)
    #expect(report.totals == .empty)
}

// MARK: - Demo-Transport

@Test func derDemoTransportVerhaeltSichWieDieDatenbank() async throws {
    let demo = KitchenLinkDemoShiftTransport(seedRevenue: 1_000, seedTips: 100, seedCash: 500)
    let config = KitchenLinkCloudConfig.sandboxDefault
    let cloudSession = session()

    var report = try await demo.loadReport(
        config: config, session: cloudSession, venueSlug: "demo", shiftID: nil
    )
    #expect(report.isOpen == false)

    try await demo.openShift(
        config: config, session: cloudSession, venueSlug: "demo",
        openingCashCents: 10_000, idempotencyKey: "k1", overrideToken: nil
    )

    // Zweites Öffnen wird abgewiesen — wie der Unique-Index.
    await #expect(throws: (any Error).self) {
        try await demo.openShift(
            config: config, session: cloudSession, venueSlug: "demo",
            openingCashCents: 0, idempotencyKey: "k2", overrideToken: nil
        )
    }

    report = try await demo.loadReport(
        config: config, session: cloudSession, venueSlug: "demo", shiftID: nil
    )
    // 100,00 Anfang + 5,00 bar
    #expect(report.totals.expectedCashCents == 10_500)

    try await demo.recordCashMovement(
        config: config, session: cloudSession, venueSlug: "demo",
        kind: .payout, amountCents: 500, reason: "Tresor", idempotencyKey: "m1",
        overrideToken: nil
    )
    // Wiederholung bucht nicht doppelt.
    try await demo.recordCashMovement(
        config: config, session: cloudSession, venueSlug: "demo",
        kind: .payout, amountCents: 500, reason: "Tresor", idempotencyKey: "m1",
        overrideToken: nil
    )

    report = try await demo.loadReport(
        config: config, session: cloudSession, venueSlug: "demo", shiftID: nil
    )
    #expect(report.totals.expectedCashCents == 10_000)

    let close = try await demo.closeShift(
        config: config, session: cloudSession, venueSlug: "demo",
        countedCashCents: 9_950, note: "", overrideToken: nil
    )
    #expect(close.zNumber == 1)
    #expect(close.varianceCents == -50)

    let history = try await demo.recentShifts(
        config: config, session: cloudSession, venueSlug: "demo", limit: 10
    )
    #expect(history.count == 1)
    #expect(history.first?.zNumber == 1)
}

// MARK: - Freigabe an der Kasse (KL-ROLE-002)

@MainActor
@Test func ohneRechtAberMitPinImLokalBietetDieKasseEineFreigabeAn() async {
    let spy = ShiftSpy(report: openReport())
    let model = KitchenLinkShiftModel(
        config: .sandboxDefault,
        transport: spy,
        permissions: ServiceRoleSpy(),
        pin: PinSpy(authorizers: 1),
        store: makeStore()
    )
    await model.load()

    #expect(model.gate(for: .shiftClose).allowsAuthorization)
    #expect(model.gate(for: .cashMovement).allowsAuthorization)

    // Die Eingaben stehen; nur die Befugnis fehlt und wird gleich geholt.
    model.countedCashText = "110,50"
    #expect(model.isReadyToClose)
    #expect(model.canClose == false)
}

@MainActor
@Test func hatNiemandEinePinBleibtEsBeiDerSperreAusKlRole001() async {
    let spy = ShiftSpy(report: openReport())
    let model = KitchenLinkShiftModel(
        config: .sandboxDefault,
        transport: spy,
        permissions: ServiceRoleSpy(),
        pin: PinSpy(authorizers: 0),
        store: makeStore()
    )
    await model.load()

    #expect(model.gate(for: .shiftClose).allowsAuthorization == false)
    #expect(model.missingPermissionNote(for: .shiftClose)?.contains("Frag Inhaber") == true)
}

@MainActor
@Test func mitFreigabeErreichtDerAbschlussDieDatenbankMitToken() async {
    let spy = ShiftSpy(report: openReport())
    await spy.setCloseResult(
        KitchenLinkShiftClose(
            shiftID: "shift-1", zNumber: 1, countedCashCents: 11_050,
            expectedCashCents: 11_050, varianceCents: 0, totals: .empty
        )
    )
    let model = KitchenLinkShiftModel(
        config: .sandboxDefault,
        transport: spy,
        permissions: ServiceRoleSpy(),
        pin: PinSpy(),
        store: makeStore()
    )
    await model.load()
    model.countedCashText = "110,50"

    // Ohne Token passiert nichts …
    await model.closeShift()
    #expect(await spy.closeCalls.isEmpty)

    // … mit Token schon, und er geht mit.
    await model.closeShift(overrideToken: "tok-1")
    #expect(await spy.closeCalls.count == 1)
    #expect(await spy.closeCalls.first?.token == "tok-1")
}

@MainActor
@Test func eineEntnahmeGehtEbensoMitFreigabe() async {
    let spy = ShiftSpy(report: openReport())
    let model = KitchenLinkShiftModel(
        config: .sandboxDefault,
        transport: spy,
        permissions: ServiceRoleSpy(),
        pin: PinSpy(),
        store: makeStore()
    )
    await model.load()
    model.movementAmountText = "12,50"

    await model.bookMovement()
    #expect(await spy.movementCalls.isEmpty)

    await model.bookMovement(overrideToken: "tok-2")
    #expect(await spy.movementCalls.first?.token == "tok-2")
}

@MainActor
@Test func auchDasOeffnenGehtMitFreigabe() async {
    let spy = ShiftSpy(report: .none)
    let model = KitchenLinkShiftModel(
        config: .sandboxDefault,
        transport: spy,
        permissions: ServiceRoleSpy(),
        pin: PinSpy(),
        store: makeStore()
    )
    await model.load()
    model.openingCashText = "150"

    await model.openShift()
    #expect(await spy.openCalls.isEmpty)

    await model.openShift(overrideToken: "tok-3")
    #expect(await spy.openCalls.first?.token == "tok-3")
    #expect(await spy.openCalls.first?.cents == 15_000)
}

@MainActor
@Test func eineInstanzOhnePinMigrationSperrtDieKasseNichtAus() async {
    // Dieselbe Lehre wie beim Bestell-Lesepfad in KL-STATION-001: eine
    // fehlende Funktion darf nicht den ganzen Bildschirm kosten.
    let spy = ShiftSpy(report: openReport())
    let model = KitchenLinkShiftModel(
        config: .sandboxDefault,
        transport: spy,
        permissions: RoleSpy(),
        pin: FailingPinSpy(),
        store: makeStore()
    )
    await model.load()

    #expect(model.phase == .ready)
    #expect(model.isOpen)
    #expect(model.canOpenShift)
}

private actor FailingPinSpy: KitchenLinkManagerPinTransport {
    func pinStatus(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> KitchenLinkManagerPinStatus {
        throw KitchenLinkCloudServiceError.server(
            status: 404, message: "function operator_manager_pin_status does not exist"
        )
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
