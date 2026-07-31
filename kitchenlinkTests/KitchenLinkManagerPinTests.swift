import Foundation
import Testing
@testable import kitchenlink

/// KL-ROLE-002: Manager-PIN als einmalige Freigabe.
///
/// Geprüft wird die Seite, die im Gerät entschieden wird: welche Aktion
/// überhaupt überbrückbar ist, wann die App eine Freigabe anbietet statt nur
/// zu sperren, und dass ein Token genau einmal und nur für seine Aktion
/// mitgeschickt wird.
///
/// Was hier NICHT bewiesen wird: dass eine Freigabe wirklich einmalig ist. Das
/// entscheidet die Datenbank — `scripts/tests/manager-pin.sql` prüft es gegen
/// echtes PostgreSQL.

// MARK: - Helfer

private func session() -> KitchenLinkCloudSession {
    KitchenLinkCloudSession(
        accessToken: "at", refreshToken: "rt", userID: "user-1", expiresAt: .distantFuture
    )
}

private func makeStore(withSession: Bool = true) -> KitchenLinkCloudCredentialStore {
    let defaults = UserDefaults(suiteName: "pin-\(UUID().uuidString)")!
    let store = KitchenLinkCloudCredentialStore(defaults: defaults, secrets: InMemorySecretStore())
    if withSession { store.save(session: session()) }
    return store
}

private let shiftLead = KitchenLinkMyRole(
    roleKey: "shift_lead", roleName: "Schichtleitung",
    permissions: ["shift.open", "shift.close", "cash.movement", "payments.refund"]
)

private let service = KitchenLinkMyRole(
    roleKey: "service", roleName: "Service", permissions: []
)

private func status(authorizers: Int, hasPin: Bool = false) -> KitchenLinkManagerPinStatus {
    KitchenLinkManagerPinStatus(hasPin: hasPin, updatedAt: nil, authorizers: authorizers)
}

private actor PinTransportSpy: KitchenLinkManagerPinTransport {
    private var results: [KitchenLinkManagerPinAuthorization]
    private(set) var pins: [String] = []
    private(set) var notes: [String?] = []
    private(set) var contexts: [[String: String]] = []

    init(results: [KitchenLinkManagerPinAuthorization]) {
        self.results = results
    }

    func pinStatus(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> KitchenLinkManagerPinStatus { status(authorizers: 1) }

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
        pins.append(pin)
        notes.append(note)
        contexts.append(context)
        return results.isEmpty ? .refused(.unknown("leer")) : results.removeFirst()
    }

    func recentOverrides(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        limit: Int
    ) async throws -> [KitchenLinkManagerOverrideRecord] { [] }
}

// MARK: - Der Zuschnitt

@Test func nurVierRechteSindUeberbrueckbar() {
    // `staff.manage` fehlt bewusst: wer per geliehener PIN Personal verwalten
    // dürfte, könnte sich in derselben Minute selbst zum Inhaber machen.
    #expect(KitchenLinkVenuePermission.pinOverridable.count == 4)
    #expect(KitchenLinkVenuePermission.staffManage.isPinOverridable == false)
    #expect(KitchenLinkVenuePermission.paymentsRefund.isPinOverridable)
    #expect(KitchenLinkVenuePermission.shiftClose.isPinOverridable)
}

@Test func einePinErgibtNurSinnWoSieEtwasFreigebenKann() {
    #expect(shiftLead.canHoldManagerPin)
    #expect(service.canHoldManagerPin == false)
    // Personal verwalten allein reicht nicht: dieses Recht ist nicht
    // überbrückbar, also könnte eine PIN dahinter nichts freigeben.
    let bookkeeper = KitchenLinkMyRole(
        roleKey: "accounting", roleName: "Buchhaltung", permissions: ["staff.manage"]
    )
    #expect(bookkeeper.canHoldManagerPin == false)
}

// MARK: - Die PIN-Regeln, gespiegelt aus der Datenbank

@Test func vierBisAchtZiffernUndKeinMuster() {
    #expect(KitchenLinkManagerPinRules.isValid("8317"))
    #expect(KitchenLinkManagerPinRules.isValid("50623917"))

    #expect(KitchenLinkManagerPinRules.isValid("831") == false)
    #expect(KitchenLinkManagerPinRules.isValid("123456789") == false)
    #expect(KitchenLinkManagerPinRules.isValid("83a7") == false)
    #expect(KitchenLinkManagerPinRules.isValid("") == false)

    // Die zwei Muster, die einen Großteil aller real vergebenen PINs ausmachen.
    #expect(KitchenLinkManagerPinRules.isValid("0000") == false)
    #expect(KitchenLinkManagerPinRules.isValid("1234") == false)
    #expect(KitchenLinkManagerPinRules.isValid("4321") == false)
    #expect(KitchenLinkManagerPinRules.isValid("9876") == false)

    #expect(KitchenLinkManagerPinRules.rejection(for: "0000")?.contains("gleiche Ziffer") == true)
    #expect(KitchenLinkManagerPinRules.rejection(for: "8317") == nil)
}

// MARK: - Was der Bildschirm anbietet

@Test func werDarfSiehtKeineHuerde() {
    #expect(
        KitchenLinkPermissionGate.evaluate(
            permission: .paymentsRefund, role: shiftLead, pinStatus: status(authorizers: 1)
        ) == .allowed
    )
}

@Test func ohneRechtAberMitEinerHinterlegtenPinGibtEsEinenWeg() {
    let gate = KitchenLinkPermissionGate.evaluate(
        permission: .paymentsRefund, role: service, pinStatus: status(authorizers: 1)
    )
    #expect(gate.allowsAuthorization)
    #expect(gate.note?.contains("Service") == true)
    #expect(gate.note?.contains("PIN") == true)
}

@Test func ohnePinImLokalBleibtEsBeiDerAnsageAusKlRole001() {
    // Ein Knopf, der in ein Blatt führt, das niemand ausfüllen kann, ist
    // schlimmer als kein Knopf.
    let gate = KitchenLinkPermissionGate.evaluate(
        permission: .paymentsRefund, role: service, pinStatus: status(authorizers: 0)
    )
    #expect(gate.allowsAuthorization == false)
    #expect(gate.note?.contains("Frag Inhaber") == true)
}

@Test func personalVerwaltenLaesstSichNieFreigeben() {
    let gate = KitchenLinkPermissionGate.evaluate(
        permission: .staffManage, role: service, pinStatus: status(authorizers: 3)
    )
    #expect(gate.allowsAuthorization == false)
}

@Test func einZugangOhnePersonalBekommtKeineFreigabe() {
    let gate = KitchenLinkPermissionGate.evaluate(
        permission: .paymentsRefund, role: .none, pinStatus: status(authorizers: 2)
    )
    #expect(gate.allowsAuthorization == false)
    #expect(gate.note?.contains("nicht zum Personal") == true)
}

// MARK: - Antworten der Datenbank

@Test func eineErteilteFreigabeWirdGelesen() throws {
    let json = """
    {"granted": true, "override_id": "o1", "token": "abc",
     "expires_at": "2026-07-31T20:05:00+00:00", "permission": "payments.refund",
     "granted_by_email": "chefin@restaurant.de"}
    """
    let result = try KitchenLinkManagerPinAuthorization.decode(Data(json.utf8))
    guard case .granted(let override) = result else {
        Issue.record("Freigabe erwartet, war \(result)")
        return
    }
    #expect(override.token == "abc")
    #expect(override.grantedByEmail == "chefin@restaurant.de")
    #expect(override.expiresAt != nil)
}

@Test func eineFalschePinIstKeinFehlerSondernEineAntwort() throws {
    // Eine Exception würde die Transaktion zurückrollen — und mit ihr den
    // hochgezählten Fehlversuch. Die Sperre griffe nie.
    let result = try KitchenLinkManagerPinAuthorization.decode(
        Data(#"{"granted": false, "reason": "pin_invalid", "attempts_left": 3}"#.utf8)
    )
    #expect(result == .refused(.invalidPin(attemptsLeft: 3)))
    if case .refused(let refusal) = result {
        #expect(refusal.message.contains("3"))
    }
}

@Test func dieUebrigenAbsagenWerdenUnterschieden() throws {
    func refusal(_ json: String) throws -> KitchenLinkManagerPinRefusal? {
        guard case .refused(let value) =
            try KitchenLinkManagerPinAuthorization.decode(Data(json.utf8)) else { return nil }
        return value
    }

    #expect(try refusal(#"{"granted": false, "reason": "pin_ambiguous"}"#) == .ambiguous)
    #expect(try refusal(#"{"granted": false, "reason": "pin_not_needed"}"#) == .notNeeded)
    #expect(try refusal(#"{"granted": false, "reason": "pin_missing"}"#) == .missingPin)
    #expect(try refusal(#"{"granted": false, "reason": "pin_locked"}"#) == .locked(until: nil))
    // Ein einzelner Fehlversuch heißt „noch ein Versuch", nicht „noch 1 Versuche".
    #expect(
        KitchenLinkManagerPinRefusal.invalidPin(attemptsLeft: 1).message
            .contains("Noch ein Versuch")
    )
    // Die Mehrdeutigkeit erklärt sich selbst: sonst sucht jemand den Fehler
    // bei der PIN statt bei der doppelten Vergabe.
    #expect(KitchenLinkManagerPinRefusal.ambiguous.message.contains("zwei Personen"))
}

@Test func eineProtokollzeileWirdGelesen() {
    let record = KitchenLinkManagerOverrideRecord.decode([
        "id": "o1",
        "permission": "payments.refund",
        "granted_by_email": "chefin@restaurant.de",
        "requested_by_email": "jonas@restaurant.de",
        "granted_at": "2026-07-31T20:00:00+00:00",
        "note": "Gast hat falsch bestellt"
    ])
    #expect(record?.permissionLabel == "Zahlung stornieren")
    // Eine erteilte, aber nie verbrauchte Freigabe ist kein Fehler — die
    // Aktion wurde abgebrochen. Sichtbar bleibt sie trotzdem.
    #expect(record?.wasUsed == false)
}

// MARK: - Das Freigabe-Blatt

@MainActor
@Test func einTokenKommtZurueckUndDiePinBleibtNichtLiegen() async {
    let spy = PinTransportSpy(results: [
        .granted(
            KitchenLinkManagerOverride(
                token: "tok-1", permission: "payments.refund",
                expiresAt: nil, grantedByEmail: "chefin@restaurant.de"
            )
        )
    ])
    let model = KitchenLinkManagerPinAuthorizationModel(
        permission: .paymentsRefund,
        note: "Storno am Tisch 3",
        context: ["payment_id": "p1"],
        transport: spy,
        store: makeStore()
    )
    model.pin = "8317"
    #expect(model.canSubmit)

    let override = await model.authorize()

    #expect(override?.token == "tok-1")
    // Die PIN gehört der Führungskraft, nicht diesem Gerät.
    #expect(model.pin.isEmpty)
    #expect(model.message == nil)
    #expect(await spy.notes.first == "Storno am Tisch 3")
    #expect(await spy.contexts.first?["payment_id"] == "p1")
}

@MainActor
@Test func eineFalschePinLoeschtDasFeldUndNenntDenRest() async {
    let spy = PinTransportSpy(results: [.refused(.invalidPin(attemptsLeft: 2))])
    let model = KitchenLinkManagerPinAuthorizationModel(
        permission: .paymentsRefund, transport: spy, store: makeStore()
    )
    model.pin = "1379"

    let override = await model.authorize()

    #expect(override == nil)
    #expect(model.pin.isEmpty)
    #expect(model.message?.contains("2") == true)
    #expect(model.isLocked == false)
}

@MainActor
@Test func nachDerSperreWirdNichtWeiterProbiert() async {
    let spy = PinTransportSpy(results: [.refused(.locked(until: Date().addingTimeInterval(300)))])
    let model = KitchenLinkManagerPinAuthorizationModel(
        permission: .cashMovement, transport: spy, store: makeStore()
    )
    model.pin = "1379"
    _ = await model.authorize()

    #expect(model.isLocked)
    model.pin = "8317"
    #expect(model.canSubmit == false)
}

@MainActor
@Test func eineUngueltigePinErreichtDenServerGarNicht() async {
    let spy = PinTransportSpy(results: [])
    let model = KitchenLinkManagerPinAuthorizationModel(
        permission: .paymentsRefund, transport: spy, store: makeStore()
    )
    model.pin = "1234"

    #expect(model.canSubmit == false)
    _ = await model.authorize()
    #expect(await spy.pins.isEmpty)
    #expect(model.message?.contains("Zahlenreihe") == true)
}

// MARK: - Der Demo-Transport verhält sich wie die Datenbank

@Test func derDemoTransportVerbrauchtEineFreigabeGenauEinmal() async throws {
    let demo = KitchenLinkDemoManagerPinTransport()
    let config = KitchenLinkCloudConfig.sandboxDefault
    let cloudSession = session()

    // Was nicht überbrückbar ist, wird auch in der Demo abgewiesen.
    await #expect(throws: (any Error).self) {
        _ = try await demo.authorize(
            config: config, session: cloudSession, venueSlug: "demo",
            permission: .staffManage, pin: KitchenLinkDemoManagerPinTransport.demoAuthorizerPin,
            note: nil, context: [:]
        )
    }

    let refused = try await demo.authorize(
        config: config, session: cloudSession, venueSlug: "demo",
        permission: .paymentsRefund, pin: "1379", note: nil, context: [:]
    )
    #expect(refused == .refused(.invalidPin(attemptsLeft: 4)))

    let granted = try await demo.authorize(
        config: config, session: cloudSession, venueSlug: "demo",
        permission: .paymentsRefund,
        pin: KitchenLinkDemoManagerPinTransport.demoAuthorizerPin,
        note: "Storno", context: [:]
    )
    guard case .granted(let override) = granted else {
        Issue.record("Freigabe erwartet, war \(granted)")
        return
    }

    try await demo.consume(token: override.token, permission: .paymentsRefund)
    // Ein zweites Mal geht nicht — wie `used_at is null` in der Datenbank.
    await #expect(throws: (any Error).self) {
        try await demo.consume(token: override.token, permission: .paymentsRefund)
    }
}

@Test func einTokenGiltNurFuerSeineAktion() async throws {
    let demo = KitchenLinkDemoManagerPinTransport()
    let granted = try await demo.authorize(
        config: .sandboxDefault, session: session(), venueSlug: "demo",
        permission: .paymentsRefund,
        pin: KitchenLinkDemoManagerPinTransport.demoAuthorizerPin,
        note: nil, context: [:]
    )
    guard case .granted(let override) = granted else {
        Issue.record("Freigabe erwartet")
        return
    }
    await #expect(throws: (any Error).self) {
        try await demo.consume(token: override.token, permission: .shiftClose)
    }
}

@Test func einePinOhneMusterWirdAuchInDerDemoAngenommen() async throws {
    let demo = KitchenLinkDemoManagerPinTransport()
    await #expect(throws: (any Error).self) {
        try await demo.setPin(
            config: .sandboxDefault, session: session(), venueSlug: "demo", pin: "1234"
        )
    }
    try await demo.setPin(
        config: .sandboxDefault, session: session(), venueSlug: "demo", pin: "8317"
    )
    let after = try await demo.pinStatus(
        config: .sandboxDefault, session: session(), venueSlug: "demo"
    )
    #expect(after.hasPin)
    #expect(after.authorizers == 2)
}
