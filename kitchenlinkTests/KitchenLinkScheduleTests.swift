import Foundation
import Testing
@testable import kitchenlink

/// KL-PLAN-001: Dienstplan.
///
/// Der Kern hier ist die Sichtbarkeit: ein **Entwurf** darf beim Betroffenen
/// nicht ankommen, und eine bereits angenommene Schicht darf nicht still
/// verschoben werden. Beides ist in der Datenbank festgeschrieben — geprüft
/// wird, dass die App dieselbe Wahrheit zeigt.

private func session() -> KitchenLinkCloudSession {
    KitchenLinkCloudSession(
        accessToken: "at", refreshToken: "rt", userID: "user-1", expiresAt: .distantFuture
    )
}

private func makeStore(withSession: Bool = true) -> KitchenLinkCloudCredentialStore {
    let defaults = UserDefaults(suiteName: "plan-\(UUID().uuidString)")!
    let store = KitchenLinkCloudCredentialStore(defaults: defaults, secrets: InMemorySecretStore())
    if withSession { store.save(session: session()) }
    return store
}

/// Der Demo-Team-Transport liefert je nach Launch-Argument Inhaber oder
/// Service. Für die Planungstests wird die Rolle hier fest gesetzt.
private actor PlannerRole: KitchenLinkTeamTransport {
    private let permissions: Set<String>
    private let inner = KitchenLinkDemoTeamTransport()

    init(_ permissions: Set<String>) { self.permissions = permissions }

    func loadMyRole(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> KitchenLinkMyRole {
        KitchenLinkMyRole(
            roleKey: "test", roleName: "Testrolle", permissions: permissions
        )
    }

    func loadTeam(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> [KitchenLinkTeamMember] {
        try await inner.loadTeam(config: config, session: session, venueSlug: venueSlug)
    }

    func loadRoles(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String
    ) async throws -> [KitchenLinkVenueRole] {
        try await inner.loadRoles(config: config, session: session, venueSlug: venueSlug)
    }

    func addStaff(
        config: KitchenLinkCloudConfig, session: KitchenLinkCloudSession,
        venueSlug: String, email: String, roleKey: String
    ) async throws {}

    func setStaffRole(
        config: KitchenLinkCloudConfig, session: KitchenLinkCloudSession,
        venueSlug: String, userID: String, roleKey: String
    ) async throws {}

    func removeStaff(
        config: KitchenLinkCloudConfig, session: KitchenLinkCloudSession,
        venueSlug: String, userID: String
    ) async throws {}
}

@MainActor
private func makeModel(
    transport: KitchenLinkScheduleTransport = KitchenLinkDemoScheduleTransport(),
    permissions: Set<String> = ["schedule.manage", "staff.manage"],
    store: KitchenLinkCloudCredentialStore? = nil
) -> KitchenLinkScheduleModel {
    KitchenLinkScheduleModel(
        config: .sandboxDefault,
        transport: transport,
        teamTransport: PlannerRole(permissions),
        // Ohne diese Zeile faellt das Modell auf den **Netzwerk**-Standardwert
        // zurueck und der Unit-Test telefoniert gegen die echte Instanz. Genau
        // das ist bei KL-LEAVE-001 einmal passiert, als der Abwesenheits-
        // Transport dazukam: 48 Tests wurden rot, ohne dass an ihnen etwas
        // falsch war.
        leaveTransport: KitchenLinkDemoLeaveTransport(),
        store: store ?? makeStore()
    )
}

// MARK: - Das Recht

@Test func dasPlanungsrechtIstEigenstaendig() {
    // Es steht neben `staff.manage`, nicht darin: eine Schichtleitung plant,
    // stellt aber niemanden ein.
    #expect(KitchenLinkVenuePermission(rawValue: "schedule.manage") == .scheduleManage)
    #expect(KitchenLinkVenuePermission.scheduleManage.label == "Dienstplan schreiben")
    // Und es ist nicht per Manager-PIN freigebbar.
    #expect(KitchenLinkVenuePermission.scheduleManage.isPinOverridable == false)
    #expect(KitchenLinkVenuePermission.shiftClose.isPinOverridable)
}

// MARK: - Lebenszyklus

@Test func nurEineVeroeffentlichteSchichtWartetAufAntwort() {
    #expect(KitchenLinkShiftPlanStatus.published.awaitsResponse)
    #expect(KitchenLinkShiftPlanStatus.draft.awaitsResponse == false)
    #expect(KitchenLinkShiftPlanStatus.accepted.awaitsResponse == false)
    #expect(KitchenLinkShiftPlanStatus.declined.awaitsResponse == false)
}

@Test func einePlanzeileWirdAusDerRpcAntwortGelesen() {
    let row: [String: Any] = [
        "id": "s-1",
        "user_id": "u-1",
        "email": "sarah@restaurant.de",
        "role_name": "Schichtleitung",
        "starts_at": "2026-08-02T15:00:00+00:00",
        "ends_at": "2026-08-02T21:00:00+00:00",
        "area": "Gastraum",
        "station": "kitchen",
        "status": "published",
        "note": "Abenddienst"
    ]
    let shift = KitchenLinkPlannedShift.decode(row)

    #expect(shift?.status == .published)
    #expect(shift?.displayName == "sarah@restaurant.de")
    #expect(shift?.placeLine == "Gastraum · Küche")
    #expect(shift?.durationSeconds == 6 * 3600)
}

@Test func eineZeileOhneZeitenWirdVerworfen() {
    // Lieber keine Schicht als eine ohne Zeitraum — die waere im Plan nicht
    // darstellbar und im Konflikt nicht pruefbar.
    #expect(KitchenLinkPlannedShift.decode(["id": "s-1"]) == nil)
    #expect(KitchenLinkPlannedShift.decode([
        "id": "s-1", "starts_at": "2026-08-02T15:00:00+00:00"
    ]) == nil)
}

@Test func ohneBereichUndStationBleibtDieZeileLeerStattLeererTrenner() {
    let row: [String: Any] = [
        "id": "s-2", "starts_at": "2026-08-02T15:00:00+00:00",
        "ends_at": "2026-08-02T21:00:00+00:00", "status": "draft"
    ]
    #expect(KitchenLinkPlannedShift.decode(row)?.placeLine == nil)
}

// MARK: - Eigene Schichten

@MainActor
@Test func einEntwurfErreichtDenBetroffenenNicht() async {
    let model = makeModel()
    await model.load()

    // Der Demo-Bestand enthaelt einen Entwurf fuer jonas und einen fuer sarah.
    #expect(model.venueShifts.contains { $0.status == .draft })
    // In den eigenen Schichten taucht kein Entwurf auf.
    #expect(model.myShifts.allSatisfy { $0.status != .draft })
}

@MainActor
@Test func wasAufAntwortWartetStehtOben() async {
    let model = makeModel()
    await model.load()

    #expect(model.shiftsAwaitingResponse.count == 1)
    #expect(model.shiftsAwaitingResponse.first?.note == "Abenddienst")
    #expect(model.confirmedShifts.count == 1)
}

@MainActor
@Test func annehmenUndAblehnenAendernDenZustand() async {
    let model = makeModel()
    await model.load()

    let shift = model.shiftsAwaitingResponse.first!
    await model.respond(to: shift, accept: true)

    #expect(model.shiftsAwaitingResponse.isEmpty)
    #expect(model.confirmedShifts.count == 2)
    #expect(model.notice == "Schicht angenommen.")
}

@MainActor
@Test func zweimalAntwortenGehtNicht() async {
    let model = makeModel()
    await model.load()

    let shift = model.shiftsAwaitingResponse.first!
    await model.respond(to: shift, accept: true)
    await model.respond(to: shift, accept: false, reason: "Doch nicht")

    #expect(model.notice?.contains("nicht mehr antworten") == true)
    #expect(model.confirmedShifts.count == 2)
}

@MainActor
@Test func eineAblehnungTraegtIhrenGrund() async {
    let model = makeModel()
    await model.load()

    let shift = model.shiftsAwaitingResponse.first!
    await model.respond(to: shift, accept: false, reason: "Arzttermin")

    let declined = model.venueShifts.first { $0.id == shift.id }
    #expect(declined?.status == .declined)
    #expect(declined?.declineReason == "Arzttermin")
}

// MARK: - Planen

@MainActor
@Test func ohneRechtGibtEsKeineWoche() async {
    let model = makeModel(permissions: [])
    await model.load()

    #expect(model.canPlan == false)
    #expect(model.venueShifts.isEmpty)
    #expect(model.team.isEmpty)
    // Die eigenen Schichten sieht man trotzdem — das ist kein Planungsrecht.
    #expect(model.myShifts.isEmpty == false)
}

@MainActor
@Test func eineUeberlappungWirdAbgewiesenUndErklaert() async {
    let model = makeModel()
    await model.load()

    // sarah arbeitet morgen 16 bis 23 Uhr; 18 bis 20 liegt mittendrin.
    let sarah = model.venueShifts.first { $0.email == "sarah@restaurant.de" }!
    let failure = await model.plan(
        userID: sarah.userID!,
        startsAt: sarah.startsAt.addingTimeInterval(2 * 3600),
        endsAt: sarah.startsAt.addingTimeInterval(4 * 3600),
        area: nil, station: nil, note: nil
    )

    // Der Grund geht an den Bogen zurueck, nicht nur an den Bildschirm
    // dahinter — sonst saehe man beim Speichern gar nichts.
    #expect(failure?.contains("schon verplant") == true)
}

@MainActor
@Test func eineAnschliessendeSchichtIstKeineUeberlappung() async {
    let model = makeModel()
    await model.load()

    let sarah = model.venueShifts.first { $0.email == "sarah@restaurant.de" }!
    let failure = await model.plan(
        userID: sarah.userID!,
        startsAt: sarah.endsAt,
        endsAt: sarah.endsAt.addingTimeInterval(3 * 3600),
        area: nil, station: nil, note: "Nachtdienst"
    )

    #expect(failure == nil)
    #expect(model.notice == "Schicht geplant.")
}

@MainActor
@Test func einEndeVorDemBeginnErreichtDenServerNicht() async {
    let model = makeModel()
    await model.load()
    let before = model.venueShifts.count

    let failure = await model.plan(
        userID: "demo-3",
        startsAt: Date().addingTimeInterval(86_400),
        endsAt: Date().addingTimeInterval(86_000),
        area: nil, station: nil, note: nil
    )

    #expect(failure?.contains("Ende muss nach dem Beginn") == true)
    #expect(model.venueShifts.count == before)
}

@MainActor
@Test func eineNeueSchichtIstEinEntwurf() async {
    let model = makeModel()
    await model.load()
    let draftsBefore = model.draftCount

    _ = await model.plan(
        userID: "demo-3",
        startsAt: model.weekStart.addingTimeInterval(5 * 86_400 + 17 * 3600),
        endsAt: model.weekStart.addingTimeInterval(5 * 86_400 + 23 * 3600),
        area: "Gastraum", station: nil, note: nil
    )

    #expect(model.draftCount == draftsBefore + 1)
}

@MainActor
@Test func dasVerschiebenEinerAngenommenenSchichtHebtDieZusageAuf() async {
    // Sonst stuende „angenommen" an einer Zeit, die niemand gesehen hat.
    let model = makeModel()
    await model.load()

    let accepted = model.venueShifts.first { $0.status == .accepted }!
    _ = await model.plan(
        userID: accepted.userID!,
        startsAt: accepted.startsAt.addingTimeInterval(3600),
        endsAt: accepted.endsAt,
        area: accepted.area, station: accepted.station, note: accepted.note,
        shiftID: accepted.id
    )

    let moved = model.venueShifts.first { $0.id == accepted.id }
    #expect(moved?.status == .published)
}

// MARK: - Veröffentlichen

@MainActor
@Test func veroeffentlichenMachtEntwuerfeSichtbarUndZaehltSie() async {
    let model = makeModel()
    await model.load()
    let drafts = model.draftCount
    #expect(drafts > 0)

    await model.publishWeek()

    #expect(model.draftCount == 0)
    #expect(model.notice?.contains("\(drafts) Schichten veröffentlicht") == true)
}

@MainActor
@Test func ohneEntwuerfeGibtEsNichtsZuVeroeffentlichen() async {
    let model = makeModel()
    await model.load()
    await model.publishWeek()
    await model.publishWeek()

    #expect(model.notice?.contains("keine Entwürfe") == true)
}

// MARK: - Woche

@MainActor
@Test func dieWocheBeginntAmMontag() async {
    let model = makeModel()
    var cal = Calendar(identifier: .gregorian)
    cal.firstWeekday = 2
    // `weekday` 2 ist Montag im gregorianischen Kalender.
    #expect(cal.component(.weekday, from: model.weekStart) == 2)
}

@MainActor
@Test func dieWocheHatSiebenTage() async {
    let model = makeModel()
    await model.load()
    #expect(model.weekDays.count == 7)
    // Jede Schicht der Woche steht an genau einem Tag.
    let placed = model.weekDays.reduce(0) { $0 + $1.shifts.count }
    #expect(placed == model.venueShifts.count)
}

@MainActor
@Test func vorUndZurueckBewegenDieWocheUmSiebenTage() async {
    let model = makeModel()
    await model.load()
    let start = model.weekStart

    await model.showWeek(offsetBy: 1)
    #expect(model.weekStart.timeIntervalSince(start) == 7 * 86_400)

    await model.showWeek(offsetBy: -1)
    #expect(model.weekStart == start)
}

// MARK: - Fehlermeldungen

@Test func dieAbsagenDesDienstplansWerdenUebersetzt() {
    #expect(KitchenLinkScheduleModel.explain("plan_overlaps: ...").contains("schon verplant"))
    #expect(KitchenLinkScheduleModel.explain("plan_not_yours: ...").contains("nicht deine"))
    #expect(KitchenLinkScheduleModel.explain("plan_unknown_staff: ...").contains("nicht zum Personal"))
    #expect(KitchenLinkScheduleModel.explain("permission_denied: ...").contains("fehlt diesem Zugang"))
    // Unbekanntes wird durchgereicht statt verschluckt.
    #expect(KitchenLinkScheduleModel.explain("Netzwerk weg") == "Netzwerk weg")
}

@MainActor
@Test func ohneAnmeldungWirdDerPlanNichtGeladen() async {
    let model = makeModel(store: makeStore(withSession: false))
    await model.load()
    #expect(model.phase == .needsSignIn)
}
