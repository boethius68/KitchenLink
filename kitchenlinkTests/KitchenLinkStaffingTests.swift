import Foundation
import Testing
@testable import kitchenlink

/// KL-STAFFING-001: Sollbesetzung.
///
/// Geprüft wird die Rechnung, die den Ausschlag gibt — **wie viele fehlen** —
/// und dass die App dieselbe Zahl zeigt wie die Datenbank. Die Datenbank
/// rechnet sie ohnehin selbst; hier geht es um den Weg von dort auf den
/// Bildschirm und um die Sätze, die daraus werden.

private func session() -> KitchenLinkCloudSession {
    KitchenLinkCloudSession(
        accessToken: "at", refreshToken: "rt", userID: "user-1", expiresAt: .distantFuture
    )
}

private func makeStore() -> KitchenLinkCloudCredentialStore {
    let defaults = UserDefaults(suiteName: "staffing-\(UUID().uuidString)")!
    let store = KitchenLinkCloudCredentialStore(defaults: defaults, secrets: InMemorySecretStore())
    store.save(session: session())
    return store
}

private actor StaffingRole: KitchenLinkTeamTransport {
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
    permissions: Set<String> = ["schedule.manage", "staff.manage"]
) -> KitchenLinkScheduleModel {
    // Plan und Bedarf teilen sich denselben Demo-Plan, damit die Abdeckung
    // ueberhaupt etwas zu zaehlen hat.
    let shifts = KitchenLinkDemoScheduleTransport()
    return KitchenLinkScheduleModel(
        config: .sandboxDefault,
        transport: shifts,
        teamTransport: StaffingRole(permissions),
        leaveTransport: KitchenLinkDemoLeaveTransport(),
        staffingTransport: KitchenLinkDemoStaffingTransport(shifts: shifts),
        store: makeStore()
    )
}

// MARK: - Modell

@Test func einBedarfWirdAusDerRpcAntwortGelesen() {
    let row: [String: Any] = [
        "id": "r-1", "weekday": 5,
        "starts_at_local": "17:00:00", "ends_at_local": "23:00:00",
        "station": "kitchen", "target_headcount": 3
    ]
    let requirement = KitchenLinkStaffingRequirement.decode(row)

    #expect(requirement?.weekdayName == "Freitag")
    // Die Datenbank liefert `HH:MM:SS`; auf dem Bildschirm steht `HH:MM`.
    #expect(requirement?.windowLabel == "17:00–23:00")
    #expect(requirement?.stationLabel == "Küche")
}

@Test func eineAbdeckungWirdAusDerRpcAntwortGelesen() {
    let row: [String: Any] = [
        "requirement_id": "r-1",
        "day": "2026-08-07",
        "starts_at": "2026-08-07T15:00:00+00:00",
        "ends_at": "2026-08-07T21:00:00+00:00",
        "target_headcount": 3,
        "planned_headcount": 1,
        "missing": 2
    ]
    let coverage = KitchenLinkStaffingCoverage.decode(row)

    #expect(coverage?.missing == 2)
    #expect(coverage?.isShort == true)
}

@Test func eineGedeckteZeileIstKeineUnterbesetzung() {
    let row: [String: Any] = [
        "requirement_id": "r-1", "day": "2026-08-07",
        "starts_at": "2026-08-07T15:00:00+00:00",
        "ends_at": "2026-08-07T21:00:00+00:00",
        "target_headcount": 2, "planned_headcount": 3, "missing": 0
    ]
    // Ueberbesetzung ist keine Unterbesetzung mit umgekehrtem Vorzeichen —
    // sie ist gar keine Meldung.
    #expect(KitchenLinkStaffingCoverage.decode(row)?.isShort == false)
}

@Test func eineUnvollstaendigeZeileWirdVerworfen() {
    #expect(KitchenLinkStaffingCoverage.decode([
        "requirement_id": "r-1", "day": "kein-datum",
        "starts_at": "2026-08-07T15:00:00+00:00",
        "ends_at": "2026-08-07T21:00:00+00:00",
        "target_headcount": 2, "planned_headcount": 0, "missing": 2
    ]) == nil)
    #expect(KitchenLinkStaffingRequirement.decode(["id": "r-1", "weekday": 5]) == nil)
}

// MARK: - Abdeckung im Modell

@MainActor
@Test func dieWocheZeigtWasFehlt() async {
    let model = makeModel()
    await model.load()

    #expect(model.requirements.count == 2)
    // Bewusst keine feste Zahl: die eigenen Demo-Schichten haengen am
    // **heutigen** Tag und fallen je nach Wochentag mal in ein Fenster und mal
    // nicht. Geprueft wird die Aussage, nicht die Arithmetik — der Freitag
    // braucht drei und hat hoechstens zwei.
    #expect(model.missingThisWeek > 0)

    let friday = Calendar(identifier: .gregorian)
        .date(byAdding: .day, value: 4, to: model.weekStart)!
    #expect(model.missingThisWeek
            == model.shortfalls(on: friday).reduce(0) { $0 + $1.missing })
}

@MainActor
@Test func einGedeckterTagMeldetNichts() async {
    let model = makeModel()
    await model.load()

    let tuesday = Calendar(identifier: .gregorian)
        .date(byAdding: .day, value: 1, to: model.weekStart)!
    #expect(model.shortfalls(on: tuesday).isEmpty)
}

@MainActor
@Test func einUnterbesetzterTagMeldetSeineLuecke() async {
    let model = makeModel()
    await model.load()

    let friday = Calendar(identifier: .gregorian)
        .date(byAdding: .day, value: 4, to: model.weekStart)!
    let gaps = model.shortfalls(on: friday)

    #expect(gaps.count == 1)
    let gap = gaps.first!
    #expect(gap.targetHeadcount == 3)
    // Ein **Entwurf** deckt sehr wohl mit: nur eine abgelehnte Schicht zaehlt
    // nicht. Am Freitag steht mindestens sarahs Entwurf.
    #expect(gap.plannedHeadcount >= 1)
    #expect(gap.plannedHeadcount < 3)
    #expect(gap.missing == gap.targetHeadcount - gap.plannedHeadcount)
}

@MainActor
@Test func ohneRechtGibtEsKeinenBedarf() async {
    let model = makeModel(permissions: [])
    await model.load()

    #expect(model.requirements.isEmpty)
    #expect(model.coverage.isEmpty)
    #expect(model.missingThisWeek == 0)
}

// MARK: - Pflegen

@MainActor
@Test func einNeuerBedarfErscheintInDerListe() async {
    let model = makeModel()
    await model.load()

    let failure = await model.addRequirement(
        weekday: 3, startsAtLocal: "11:00:00", endsAtLocal: "15:00:00",
        targetHeadcount: 2, station: "bar"
    )

    #expect(failure == nil)
    #expect(model.requirements.count == 3)
    #expect(model.notice == "Bedarf gespeichert.")
}

@MainActor
@Test func einFensterMitEndeVorDemBeginnWirdAbgewiesen() async {
    let model = makeModel()
    await model.load()

    let failure = await model.addRequirement(
        weekday: 3, startsAtLocal: "15:00:00", endsAtLocal: "11:00:00",
        targetHeadcount: 2, station: nil
    )

    #expect(failure?.contains("Ende muss nach dem Beginn") == true)
    #expect(model.requirements.count == 2)
}

@MainActor
@Test func einBedarfOhnePersonWirdAbgewiesen() async {
    let model = makeModel()
    await model.load()

    let failure = await model.addRequirement(
        weekday: 3, startsAtLocal: "11:00:00", endsAtLocal: "15:00:00",
        targetHeadcount: 0, station: nil
    )

    #expect(failure?.contains("mindestens eine Person") == true)
}

@MainActor
@Test func einBedarfLaesstSichEntfernen() async {
    let model = makeModel()
    await model.load()

    await model.deleteRequirement(model.requirements.first!)

    #expect(model.requirements.count == 1)
    #expect(model.notice == "Bedarf entfernt.")
}

// MARK: - Der Demo-Transport rechnet wie die Datenbank

@Test func derDemoTransportZaehltNurUeberlappendeUndNichtAbgelehnte() async throws {
    let shifts = KitchenLinkDemoScheduleTransport()
    let staffing = KitchenLinkDemoStaffingTransport(shifts: shifts)
    let config = KitchenLinkCloudConfig.sandboxDefault
    let cloudSession = session()

    var cal = Calendar(identifier: .gregorian)
    cal.firstWeekday = 2
    let weekStart = cal.dateInterval(of: .weekOfYear, for: Date())!.start
    let tuesday = cal.date(byAdding: .day, value: 1, to: weekStart)!

    let coverage = try await staffing.loadCoverage(
        config: config, session: cloudSession, venueSlug: "demo",
        from: tuesday, to: tuesday
    )

    #expect(coverage.count == 1)
    // Dienstag 16–23 Uhr: sarah (16–23) und mira (15–22) ueberlappen beide.
    #expect(coverage.first?.plannedHeadcount == 2)
    #expect(coverage.first?.missing == 0)
}

@Test func derDemoTransportFiltertDieStation() async throws {
    let shifts = KitchenLinkDemoScheduleTransport()
    let staffing = KitchenLinkDemoStaffingTransport(shifts: shifts, seeded: false)
    let config = KitchenLinkCloudConfig.sandboxDefault
    let cloudSession = session()

    var cal = Calendar(identifier: .gregorian)
    cal.firstWeekday = 2
    let weekStart = cal.dateInterval(of: .weekOfYear, for: Date())!.start
    let tuesday = cal.date(byAdding: .day, value: 1, to: weekStart)!

    // Nur die Kueche: von den beiden Dienstagsschichten traegt eine die
    // Station `kitchen`.
    try await staffing.upsertRequirement(
        config: config, session: cloudSession, venueSlug: "demo",
        weekday: 2, startsAtLocal: "16:00:00", endsAtLocal: "23:00:00",
        targetHeadcount: 2, station: "kitchen", area: nil
    )

    let coverage = try await staffing.loadCoverage(
        config: config, session: cloudSession, venueSlug: "demo",
        from: tuesday, to: tuesday
    )

    #expect(coverage.first?.plannedHeadcount == 1)
    #expect(coverage.first?.missing == 1)
}

@Test func derDemoTransportWeistUnsinnAb() async {
    let staffing = KitchenLinkDemoStaffingTransport(seeded: false)
    let config = KitchenLinkCloudConfig.sandboxDefault
    let cloudSession = session()

    await #expect(throws: (any Error).self) {
        try await staffing.upsertRequirement(
            config: config, session: cloudSession, venueSlug: "demo",
            weekday: 9, startsAtLocal: "17:00:00", endsAtLocal: "23:00:00",
            targetHeadcount: 1, station: nil, area: nil
        )
    }
    await #expect(throws: (any Error).self) {
        try await staffing.deleteRequirement(
            config: config, session: cloudSession, venueSlug: "demo",
            requirementID: "gibt-es-nicht"
        )
    }
}
