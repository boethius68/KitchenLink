import Foundation
import Testing
@testable import kitchenlink

/// KL-TIME-001: Zeiterfassung.
///
/// Teuer, wenn falsch: die Rechnung „brutto minus Pause". Sie entscheidet am
/// Monatsende über Geld. Deshalb prüft die Datenbank sie ohnehin selbst — hier
/// wird geprüft, dass die App dieselbe Zahl **anzeigt** und die laufende Uhr
/// während einer Pause stehen bleibt.

private func session() -> KitchenLinkCloudSession {
    KitchenLinkCloudSession(
        accessToken: "at", refreshToken: "rt", userID: "user-1", expiresAt: .distantFuture
    )
}

private func makeStore(withSession: Bool = true) -> KitchenLinkCloudCredentialStore {
    let defaults = UserDefaults(suiteName: "time-\(UUID().uuidString)")!
    let store = KitchenLinkCloudCredentialStore(defaults: defaults, secrets: InMemorySecretStore())
    if withSession { store.save(session: session()) }
    return store
}

private actor OwnerRole: KitchenLinkPermissionTransport {
    func loadMyRole(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> KitchenLinkMyRole {
        KitchenLinkMyRole(
            roleKey: "owner", roleName: "Inhaber",
            permissions: ["shift.open", "shift.close", "cash.movement",
                          "payments.refund", "staff.manage"]
        )
    }
}

private actor KitchenRole: KitchenLinkPermissionTransport {
    func loadMyRole(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> KitchenLinkMyRole {
        KitchenLinkMyRole(roleKey: "kitchen", roleName: "Küche", permissions: [])
    }
}

@MainActor
private func makeModel(
    transport: KitchenLinkTimeClockTransport,
    permissions: KitchenLinkPermissionTransport = OwnerRole(),
    store: KitchenLinkCloudCredentialStore? = nil
) -> KitchenLinkTimeClockModel {
    KitchenLinkTimeClockModel(
        config: .sandboxDefault,
        transport: transport,
        permissions: permissions,
        store: store ?? makeStore()
    )
}

// MARK: - Dauern lesbar machen

@Test func dauernWerdenLesbarGeschrieben() {
    #expect(KitchenLinkDurationText.hoursMinutes(0) == "0 min")
    #expect(KitchenLinkDurationText.hoursMinutes(840) == "14 min")
    #expect(KitchenLinkDurationText.hoursMinutes(7_523) == "2:05 h")
    #expect(KitchenLinkDurationText.hoursMinutes(-5) == "0 min")

    #expect(KitchenLinkDurationText.running(0) == "0:00:00")
    #expect(KitchenLinkDurationText.running(7_523) == "2:05:23")
}

// MARK: - Netto ist brutto minus Pause

@Test func dieSummenWerdenAusDerRpcAntwortGelesen() throws {
    let json = """
    {
      "clocked_in": true,
      "entry_id": "e-1",
      "started_at": "2026-08-01T08:00:00+00:00",
      "on_break": true,
      "break_started_at": "2026-08-01T10:00:00+00:00",
      "current": {"gross_seconds": 7200, "break_seconds": 1800, "net_seconds": 5400},
      "today_net_seconds": 5400,
      "today": [
        {"id": "e-1", "started_at": "2026-08-01T08:00:00+00:00", "ended_at": null,
         "status": "open", "corrected": false,
         "totals": {"gross_seconds": 7200, "break_seconds": 1800, "net_seconds": 5400}}
      ]
    }
    """
    let status = try KitchenLinkTimeStatus.decode(Data(json.utf8))

    #expect(status.clockedIn)
    #expect(status.onBreak)
    #expect(status.current?.netSeconds == 5_400)
    #expect(status.current?.breakSeconds == 1_800)
    #expect(status.today.count == 1)
    #expect(status.today.first?.isOpen == true)
}

@Test func einStatusOhneEintragIstKeinFehler() throws {
    let status = try KitchenLinkTimeStatus.decode(
        Data(#"{"clocked_in": false, "entry_id": null, "today": [], "today_net_seconds": 0}"#.utf8)
    )
    #expect(status.clockedIn == false)
    #expect(status.current == nil)
    #expect(status.today.isEmpty)
}

// MARK: - Die laufende Uhr

@MainActor
@Test func dieUhrLaeuftZwischenZweiServerantwortenWeiter() async {
    let demo = KitchenLinkDemoTimeClockTransport()
    let model = makeModel(transport: demo)
    await model.load()
    await model.toggleClock()

    let first = model.runningNetSeconds
    model.advance(to: Date().addingTimeInterval(60))
    #expect(model.runningNetSeconds >= first + 59)
}

@MainActor
@Test func waehrendDerPauseStehtDieArbeitszeitStill() async {
    // Der Kern: eine Pause zaehlt nicht als Arbeit. Liefe die Anzeige weiter,
    // wuerde am Monatsende eine andere Zahl stehen als in der Datenbank.
    let demo = KitchenLinkDemoTimeClockTransport()
    let model = makeModel(transport: demo)
    await model.load()
    await model.toggleClock()
    await model.toggleBreak()

    #expect(model.status.onBreak)
    let atBreakStart = model.runningNetSeconds
    model.advance(to: Date().addingTimeInterval(300))
    #expect(model.runningNetSeconds == atBreakStart)
    // Die Pausenuhr laeuft dagegen sehr wohl.
    #expect(model.runningBreakSeconds >= 299)
}

// MARK: - Stempeln

@MainActor
@Test func einUndAusstempelnWechselnDenZustand() async {
    let demo = KitchenLinkDemoTimeClockTransport()
    let model = makeModel(transport: demo)
    await model.load()
    #expect(model.status.clockedIn == false)

    await model.toggleClock()
    #expect(model.status.clockedIn)
    #expect(model.notice == "Eingestempelt.")

    await model.toggleClock()
    #expect(model.status.clockedIn == false)
    #expect(model.notice == "Ausgestempelt.")
}

@MainActor
@Test func ausstempelnBeendetEineLaufendePauseMit() async {
    let demo = KitchenLinkDemoTimeClockTransport()
    let model = makeModel(transport: demo)
    await model.load()
    await model.toggleClock()
    await model.toggleBreak()
    #expect(model.status.onBreak)

    await model.toggleClock()

    #expect(model.status.clockedIn == false)
    #expect(model.status.onBreak == false)
}

@MainActor
@Test func ohneEinstempelnGibtEsKeinePause() async {
    let demo = KitchenLinkDemoTimeClockTransport()
    let model = makeModel(transport: demo)
    await model.load()

    await model.toggleBreak()

    #expect(model.notice?.contains("nur, wenn du eingestempelt bist") == true)
}

@Test func dieAbsagenDerDatenbankWerdenUebersetzt() {
    #expect(KitchenLinkTimeClockModel.explain("time_already_clocked_in: ...")
        .contains("anderen Gerät"))
    #expect(KitchenLinkTimeClockModel.explain("time_not_clocked_in: ...")
        .contains("nicht eingestempelt"))
    #expect(KitchenLinkTimeClockModel.explain("time_correction_needs_reason: ...")
        .contains("ohne Grund"))
    #expect(KitchenLinkTimeClockModel.explain("permission_denied: ...")
        .contains("fehlt diesem Zugang"))
    // Unbekanntes wird durchgereicht statt verschluckt.
    #expect(KitchenLinkTimeClockModel.explain("Netzwerk weg") == "Netzwerk weg")
}

// MARK: - Team

@MainActor
@Test func ohneStaffManageGibtEsKeinenTeamStand() async {
    let demo = KitchenLinkDemoTimeClockTransport()
    let model = makeModel(transport: demo, permissions: KitchenRole())
    await model.load()

    #expect(model.canSeeTeam == false)
    #expect(model.team.isEmpty)
    // Die eigene Zeit sieht die Küche sehr wohl.
    #expect(model.status.today.isEmpty == false)
}

@MainActor
@Test func alsInhaberIstSichtbarWerGeradeArbeitet() async {
    let demo = KitchenLinkDemoTimeClockTransport()
    let model = makeModel(transport: demo)
    await model.load()

    #expect(model.canSeeTeam)
    #expect(model.onTheClock.count == 3)
    #expect(model.finishedToday.count == 1)
    #expect(model.onTheClock.contains { $0.onBreak })
}

@MainActor
@Test func einVergessenerAusstempelWirdErkannt() async {
    // Der Alltagsfall: Jonas steht seit zwanzig Stunden auf der Uhr. Ohne
    // Korrektur kaeme er nie wieder darauf — das erklaert der Bildschirm auch.
    let demo = KitchenLinkDemoTimeClockTransport()
    let model = makeModel(transport: demo)
    await model.load()

    #expect(model.forgottenClockOuts.count == 1)
    #expect(model.forgottenClockOuts.first?.email == "jonas@restaurant.de")
    // Die anderen beiden sind erst zwei bzw. vier Stunden dabei.
    #expect(model.onTheClock.count == 3)
}

@MainActor
@Test func eineKorrekturSchliesstDenEintragUndBrauchtEinenGrund() async {
    let demo = KitchenLinkDemoTimeClockTransport()
    let model = makeModel(transport: demo)
    await model.load()

    let forgotten = model.forgottenClockOuts.first!
    let end = forgotten.startedAt!.addingTimeInterval(8 * 3600)

    // Ohne Grund passiert nichts.
    await model.correct(forgotten, endedAt: end, reason: "   ")
    #expect(model.forgottenClockOuts.count == 1)
    #expect(model.notice?.contains("ohne Grund") == true)

    // Ein Ende vor dem Beginn ebenfalls nicht.
    await model.correct(
        forgotten, endedAt: forgotten.startedAt!.addingTimeInterval(-60), reason: "Vergessen"
    )
    #expect(model.forgottenClockOuts.count == 1)

    await model.correct(forgotten, endedAt: end, reason: "Ausstempeln vergessen")

    #expect(model.forgottenClockOuts.isEmpty)
    let corrected = model.finishedToday.first { $0.id == forgotten.id }
    #expect(corrected?.corrected == true)
    #expect(corrected?.correctionReason == "Ausstempeln vergessen")
    #expect(corrected?.totals.netSeconds == 8 * 3600)
    #expect(model.notice?.contains("ursprüngliche Stand bleibt") == true)
}

// MARK: - Anmeldung

@MainActor
@Test func ohneAnmeldungWirdDieUhrNichtGeladen() async {
    let model = makeModel(
        transport: KitchenLinkDemoTimeClockTransport(), store: makeStore(withSession: false)
    )
    await model.load()
    #expect(model.phase == .needsSignIn)
}

// MARK: - Demo-Transport verhält sich wie die Datenbank

@Test func derDemoTransportWeistZweimalEinstempelnAb() async throws {
    let demo = KitchenLinkDemoTimeClockTransport(seeded: false)
    let config = KitchenLinkCloudConfig.sandboxDefault
    let cloudSession = session()

    try await demo.clockIn(config: config, session: cloudSession, venueSlug: "demo")
    await #expect(throws: (any Error).self) {
        try await demo.clockIn(config: config, session: cloudSession, venueSlug: "demo")
    }

    try await demo.startBreak(
        config: config, session: cloudSession, venueSlug: "demo", kind: .mealBreak
    )
    await #expect(throws: (any Error).self) {
        try await demo.startBreak(
            config: config, session: cloudSession, venueSlug: "demo", kind: .restBreak
        )
    }

    try await demo.clockOut(config: config, session: cloudSession, venueSlug: "demo")
    await #expect(throws: (any Error).self) {
        try await demo.clockOut(config: config, session: cloudSession, venueSlug: "demo")
    }

    // Nach dem Ausstempeln geht ein neuer Eintrag: die Sperre galt dem offenen.
    try await demo.clockIn(config: config, session: cloudSession, venueSlug: "demo")
    let status = try await demo.loadStatus(
        config: config, session: cloudSession, venueSlug: "demo"
    )
    #expect(status.clockedIn)
    #expect(status.today.count == 2)
}
