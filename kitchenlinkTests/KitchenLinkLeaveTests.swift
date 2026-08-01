import Foundation
import Testing
@testable import kitchenlink

/// KL-LEAVE-001: Abwesenheiten.
///
/// Geprüft wird vor allem die **Asymmetrie**, weil beide Hälften einzeln
/// plausibel klingen und erst zusammen den Betrieb abbilden: ein Antrag
/// blockiert die Planung noch nicht, eine Genehmigung schon — und eine
/// Genehmigung auf bereits geplante Schichten wird trotzdem erteilt und meldet
/// sie nur.

private func session() -> KitchenLinkCloudSession {
    KitchenLinkCloudSession(
        accessToken: "at", refreshToken: "rt", userID: "user-1", expiresAt: .distantFuture
    )
}

private func makeStore(withSession: Bool = true) -> KitchenLinkCloudCredentialStore {
    let defaults = UserDefaults(suiteName: "leave-\(UUID().uuidString)")!
    let store = KitchenLinkCloudCredentialStore(defaults: defaults, secrets: InMemorySecretStore())
    if withSession { store.save(session: session()) }
    return store
}

private actor LeaveRole: KitchenLinkTeamTransport {
    private let permissions: Set<String>
    private let inner = KitchenLinkDemoTeamTransport()

    init(_ permissions: Set<String>) { self.permissions = permissions }

    func loadMyRole(
        config: KitchenLinkCloudConfig, session: KitchenLinkCloudSession, venueSlug: String
    ) async throws -> KitchenLinkMyRole {
        KitchenLinkMyRole(roleKey: "test", roleName: "Testrolle", permissions: permissions)
    }

    func loadTeam(
        config: KitchenLinkCloudConfig, session: KitchenLinkCloudSession, venueSlug: String
    ) async throws -> [KitchenLinkTeamMember] {
        try await inner.loadTeam(config: config, session: session, venueSlug: venueSlug)
    }

    func loadRoles(
        config: KitchenLinkCloudConfig, session: KitchenLinkCloudSession, venueSlug: String
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
    leaveTransport: KitchenLinkLeaveTransport = KitchenLinkDemoLeaveTransport(),
    permissions: Set<String> = ["schedule.manage", "staff.manage"],
    store: KitchenLinkCloudCredentialStore? = nil
) -> KitchenLinkScheduleModel {
    KitchenLinkScheduleModel(
        config: .sandboxDefault,
        transport: KitchenLinkDemoScheduleTransport(),
        teamTransport: LeaveRole(permissions),
        leaveTransport: leaveTransport,
        store: store ?? makeStore()
    )
}

// MARK: - Modell

@Test func dieFuenfAbwesenheitsartenSindBenannt() {
    // Dieselben fünf wie `WorkforceLeaveType` in der Domäne.
    #expect(KitchenLinkLeaveKind.allCases.count == 5)
    #expect(KitchenLinkLeaveKind(rawValue: "sick")?.label == "Krank")
    #expect(KitchenLinkLeaveKind(rawValue: "sabbatical") == nil)
}

@Test func nurEinAntragIstOffen() {
    #expect(KitchenLinkLeaveStatus.requested.isOpen)
    #expect(KitchenLinkLeaveStatus.approved.isOpen == false)
    #expect(KitchenLinkLeaveStatus.rejected.isOpen == false)
    #expect(KitchenLinkLeaveStatus.cancelled.isOpen == false)
}

@Test func eineAbwesenheitWirdAusDerRpcAntwortGelesen() {
    let row: [String: Any] = [
        "id": "l-1",
        "user_id": "u-1",
        "email": "jonas@restaurant.de",
        "role_name": "Service",
        "starts_at": "2026-08-10T00:00:00+00:00",
        "ends_at": "2026-08-13T00:00:00+00:00",
        "kind": "vacation",
        "status": "requested",
        "reason": "Kurzurlaub",
        "conflicting_shifts": 2
    ]
    let leave = KitchenLinkLeave.decode(row)

    #expect(leave?.kind == .vacation)
    #expect(leave?.status == .requested)
    #expect(leave?.conflictingShifts == 2)
    // Drei Tage: 10., 11., 12. — das Ende ist exklusiv.
    #expect(leave?.dayCount == 3)
}

@Test func eineZeileMitUnbekannterArtWirdVerworfen() {
    // Lieber keine Abwesenheit als eine, deren Art die App nicht kennt.
    #expect(KitchenLinkLeave.decode([
        "id": "l-1", "starts_at": "2026-08-10T00:00:00+00:00",
        "ends_at": "2026-08-13T00:00:00+00:00", "kind": "sabbatical", "status": "requested"
    ]) == nil)
    #expect(KitchenLinkLeave.decode([
        "id": "l-1", "starts_at": "2026-08-10T00:00:00+00:00",
        "ends_at": "2026-08-13T00:00:00+00:00", "kind": "vacation", "status": "pending"
    ]) == nil)
}

// MARK: - Eigene Anträge

@MainActor
@Test func dieEigenenAbwesenheitenWerdenGeladen() async {
    let model = makeModel()
    await model.load()

    #expect(model.myLeaves.count == 1)
    #expect(model.myOpenLeaves.count == 1)
    #expect(model.myLeaves.first?.kind == .vacation)
}

@MainActor
@Test func beantragenBrauchtKeinRecht() async {
    // Es ist die eigene Abwesenheit — auch ohne jedes Recht.
    let model = makeModel(permissions: [])
    await model.load()

    let failure = await model.requestLeave(
        startsAt: Date().addingTimeInterval(40 * 86_400),
        endsAt: Date().addingTimeInterval(43 * 86_400),
        kind: .unpaid, reason: nil
    )

    #expect(failure == nil)
    #expect(model.myLeaves.count == 2)
    #expect(model.notice?.contains("beantragt") == true)
}

@MainActor
@Test func einAntragMitEndeVorDemBeginnErreichtDenServerNicht() async {
    let model = makeModel()
    await model.load()

    let failure = await model.requestLeave(
        startsAt: Date().addingTimeInterval(40 * 86_400),
        endsAt: Date().addingTimeInterval(39 * 86_400),
        kind: .vacation, reason: nil
    )

    #expect(failure?.contains("Ende muss nach dem Beginn") == true)
    #expect(model.myLeaves.count == 1)
}

@MainActor
@Test func einAntragLaesstSichZurueckziehen() async {
    let model = makeModel()
    await model.load()

    let leave = model.myOpenLeaves.first!
    await model.cancelLeave(leave)

    #expect(model.myOpenLeaves.isEmpty)
    #expect(model.myLeaves.first { $0.id == leave.id }?.status == .cancelled)
    #expect(model.notice == "Antrag zurückgezogen.")
}

@MainActor
@Test func eineEntschiedeneAbwesenheitLaesstSichNichtZurueckziehen() async {
    let model = makeModel()
    await model.load()

    let leave = model.myOpenLeaves.first!
    await model.cancelLeave(leave)
    await model.cancelLeave(leave)

    #expect(model.notice?.contains("bereits entschieden") == true)
}

// MARK: - Die Asymmetrie

@MainActor
@Test func genehmigenBrauchtDasPlanungsrecht() async {
    let model = makeModel(permissions: [])
    await model.load()

    // Ohne `schedule.manage` gibt es die Anträge der anderen gar nicht.
    #expect(model.openLeaveRequests.isEmpty)
    #expect(model.venueLeaves.isEmpty)
}

@MainActor
@Test func offeneAntraegeStehenMitIhrerKollisionszahlDa() async {
    let model = makeModel()
    await model.load()

    #expect(model.openLeaveRequests.count == 2)
    let sick = model.openLeaveRequests.first { $0.kind == .sick }
    #expect(sick?.displayName == "jonas@restaurant.de")
    // Genau die Zahl, die den Ausschlag gibt.
    #expect(sick?.conflictingShifts == 1)
}

@MainActor
@Test func eineGenehmigungTrotzKollisionWirdErteiltUndBenannt() async {
    // Die Haelfte, die im Betrieb zaehlt: eine Krankmeldung kommt nach dem
    // Dienstplan. Wer krank ist, ist krank.
    let model = makeModel()
    await model.load()

    let sick = model.openLeaveRequests.first { $0.kind == .sick }!
    await model.review(sick, approve: true)

    #expect(model.venueLeaves.first { $0.id == sick.id }?.status == .approved)
    #expect(model.notice?.contains("neu besetzt") == true)
    #expect(model.notice?.contains("Eine geplante Schicht") == true)
}

@MainActor
@Test func ohneKollisionBleibtDieMeldungSchlicht() async {
    let model = makeModel()
    await model.load()

    let mine = model.openLeaveRequests.first { $0.kind == .vacation }!
    await model.review(mine, approve: true)

    #expect(model.notice == "Genehmigt.")
}

@MainActor
@Test func eineAblehnungMeldetKeineKollision() async {
    // Sie aendert am Plan nichts, also gibt es auch nichts neu zu besetzen.
    let model = makeModel()
    await model.load()

    let sick = model.openLeaveRequests.first { $0.kind == .sick }!
    await model.review(sick, approve: false, note: "Zu kurzfristig")

    #expect(model.venueLeaves.first { $0.id == sick.id }?.status == .rejected)
    #expect(model.notice == "Abgelehnt.")
}

@MainActor
@Test func zweimalEntscheidenGehtNicht() async {
    let model = makeModel()
    await model.load()

    let leave = model.openLeaveRequests.first!
    await model.review(leave, approve: true)
    await model.review(leave, approve: false)

    #expect(model.notice?.contains("bereits entschieden") == true)
}

@MainActor
@Test func inEinenGenehmigtenZeitraumWirdNichtsBeantragt() async {
    let model = makeModel()
    await model.load()

    // Mira hat eine genehmigte Schulung; fuer den eigenen Zugang wird eine
    // Genehmigung erzeugt und dann derselbe Zeitraum erneut beantragt.
    let mine = model.openLeaveRequests.first { $0.kind == .vacation }!
    await model.review(mine, approve: true)

    let failure = await model.requestLeave(
        startsAt: mine.startsAt.addingTimeInterval(86_400),
        endsAt: mine.endsAt.addingTimeInterval(-86_400),
        kind: .sick, reason: nil
    )

    #expect(failure?.contains("bereits etwas genehmigt") == true)
}

// MARK: - Fehlermeldungen

@Test func dieAbsagenDerAbwesenheitenWerdenUebersetzt() {
    #expect(KitchenLinkScheduleModel.explain("plan_on_leave: ...")
        .contains("genehmigte Abwesenheit"))
    #expect(KitchenLinkScheduleModel.explain("leave_already_approved: ...")
        .contains("bereits etwas genehmigt"))
    #expect(KitchenLinkScheduleModel.explain("leave_not_yours: ...")
        .contains("nicht dein Antrag"))
    #expect(KitchenLinkScheduleModel.explain("leave_already_decided: ...")
        .contains("bereits entschieden"))
}
