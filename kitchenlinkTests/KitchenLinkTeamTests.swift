import Foundation
import Testing
@testable import kitchenlink

/// KL-ROLE-001: Rollen und Rechte.
///
/// Zwei Dinge werden hier geprüft: dass die App die Sperren der Datenbank
/// **vorher** kennt (statt den Nutzer in einen Serverfehler laufen zu lassen),
/// und dass ihre Fehlermeldungen im Betrieb weiterhelfen — „staff_last_owner"
/// hilft niemandem an der Kasse.

private func session() -> KitchenLinkCloudSession {
    KitchenLinkCloudSession(
        accessToken: "at", refreshToken: "rt", userID: "user-1", expiresAt: .distantFuture
    )
}

private func makeStore(withSession: Bool = true) -> KitchenLinkCloudCredentialStore {
    let defaults = UserDefaults(suiteName: "team-\(UUID().uuidString)")!
    let store = KitchenLinkCloudCredentialStore(defaults: defaults, secrets: InMemorySecretStore())
    if withSession { store.save(session: session()) }
    return store
}

@MainActor
private func makeModel(
    transport: KitchenLinkTeamTransport,
    store: KitchenLinkCloudCredentialStore? = nil
) -> KitchenLinkTeamModel {
    KitchenLinkTeamModel(
        config: .sandboxDefault,
        transport: transport,
        store: store ?? makeStore()
    )
}

// MARK: - Rechtemodell

@Test func jedesRechtIstBenanntUndNichtsDarueberHinaus() {
    // Der Zuschnitt bleibt eng: was hier steht, wird auch geprüft — und was
    // nirgends geprüft wird, steht nicht hier. Bewusst **keine** Zählung: die
    // brach beim sechsten Recht (KL-PLAN-001), ohne dass sich am Sinn etwas
    // geändert hätte.
    #expect(KitchenLinkVenuePermission(rawValue: "shift.close")?.label == "Kasse abschließen")
    #expect(KitchenLinkVenuePermission(rawValue: "schedule.manage") != nil)
    #expect(KitchenLinkVenuePermission(rawValue: "menu.publish") == nil)
    #expect(KitchenLinkVenuePermission(rawValue: "tables.manage") == nil)

    // Jedes Recht trägt eine Bezeichnung und einen verneinten Satzteil.
    for permission in KitchenLinkVenuePermission.allCases {
        #expect(!permission.label.isEmpty)
        #expect(permission.deniedClause.contains("nicht") || permission.deniedClause.contains("kein"))
    }
}

@Test func eineRolleOhneSensibleRechteIstEineAussageKeinMangel() {
    let service = KitchenLinkVenueRole(
        key: "service", name: "Service", permissions: [], isBuiltin: true, sortOrder: 40
    )
    #expect(service.permissionSummary == "Nur Alltag, nichts Sensibles")

    let lead = KitchenLinkVenueRole(
        key: "shift_lead", name: "Schichtleitung",
        permissions: ["shift.open", "shift.close"], isBuiltin: true, sortOrder: 30
    )
    #expect(lead.permissionSummary.contains("Kasse abschließen"))
}

@Test func meineRechteWerdenAusDerRpcAntwortGelesen() throws {
    let json = """
    {"role": "shift_lead", "role_name": "Schichtleitung",
     "permissions": ["shift.open", "shift.close", "cash.movement", "payments.refund"]}
    """
    let role = try KitchenLinkMyRole.decode(Data(json.utf8))

    #expect(role.isStaff)
    #expect(role.can(.shiftClose))
    #expect(role.can(.staffManage) == false)
}

@Test func einZugangOhnePersonalHatKeineRolle() throws {
    let role = try KitchenLinkMyRole.decode(
        Data(#"{"role": null, "role_name": null, "permissions": []}"#.utf8)
    )
    #expect(role.isStaff == false)
    #expect(KitchenLinkVenuePermission.allCases.allSatisfy { !role.can($0) })
}

@Test func einMitgliedOhneLesbareEMailBehaeltSeineKennung() {
    let member = KitchenLinkTeamMember(
        userID: "abcdef12-3456", email: nil,
        roleKey: "service", roleName: "Service", isMe: false
    )
    // Lieber eine unschöne Zeile als ein namenloser Eintrag.
    #expect(member.displayName == "abcdef12")
}

// MARK: - Fehlermeldungen, die weiterhelfen

@Test func dieSperrenDerDatenbankWerdenUebersetzt() {
    #expect(KitchenLinkTeamModel.explain("staff_self_change: ...").contains("eigene Rolle"))
    #expect(KitchenLinkTeamModel.explain("staff_last_owner: ...").contains("mindestens einen Inhaber"))
    #expect(KitchenLinkTeamModel.explain("staff_owner_protected: ...").contains("Nur ein Inhaber"))
    #expect(KitchenLinkTeamModel.explain("permission_denied: ...").contains("fehlt diesem Zugang"))
    // Unbekanntes wird durchgereicht statt verschluckt.
    #expect(KitchenLinkTeamModel.explain("Netzwerk weg") == "Netzwerk weg")
}

// MARK: - Der Bildschirm ist selbst rechtepflichtig

@MainActor
@Test func ohneRechtWirdDasTeamGarNichtErstGeladen() async {
    let transport = KitchenLinkDemoTeamTransport(members: [
        KitchenLinkTeamMember(
            userID: "demo-me", email: "ich@restaurant.de",
            roleKey: "service", roleName: "Service", isMe: true
        )
    ])
    let model = makeModel(transport: transport)

    await model.load()

    #expect(model.canManage == false)
    #expect(model.members.isEmpty)
    if case .notAllowed(let message) = model.phase {
        #expect(message.contains("Service"))
    } else {
        Issue.record("notAllowed erwartet, war \(model.phase)")
    }
    // Die Rollenübersicht bleibt sichtbar: sie zu lesen ist kein Eingriff.
    #expect(model.roles.count == 9)
}

@MainActor
@Test func alsInhaberWirdDasTeamGeladen() async {
    let model = makeModel(transport: KitchenLinkDemoTeamTransport())

    await model.load()

    #expect(model.phase == .ready)
    #expect(model.canManage)
    #expect(model.members.count == 4)
    #expect(model.myRole.roleKey == "owner")
}

@MainActor
@Test func ohneAnmeldungWirdDasTeamNichtGeladen() async {
    let model = makeModel(
        transport: KitchenLinkDemoTeamTransport(), store: makeStore(withSession: false)
    )
    await model.load()
    #expect(model.phase == .needsSignIn)
}

// MARK: - Ändern

@MainActor
@Test func eineRolleWirdGeaendertUndDasTeamNeuGeladen() async {
    let model = makeModel(transport: KitchenLinkDemoTeamTransport())
    await model.load()

    let jonas = model.members.first { $0.email == "jonas@restaurant.de" }!
    #expect(jonas.roleKey == "service")

    await model.setRole(for: jonas, to: "shift_lead")

    let updated = model.members.first { $0.email == "jonas@restaurant.de" }!
    #expect(updated.roleKey == "shift_lead")
    #expect(model.notice?.contains("Schichtleitung") == true)
}

@MainActor
@Test func dieEigeneRolleLaesstSichNichtAendern() async {
    let model = makeModel(transport: KitchenLinkDemoTeamTransport())
    await model.load()

    let me = model.members.first(where: \.isMe)!
    await model.setRole(for: me, to: "service")

    #expect(model.members.first(where: \.isMe)?.roleKey == "owner")
    #expect(model.notice?.contains("aussperren") == true)
}

@MainActor
@Test func derLetzteInhaberBleibtInhaber() async {
    let model = makeModel(transport: KitchenLinkDemoTeamTransport(members: [
        KitchenLinkTeamMember(
            userID: "demo-me", email: "ich@restaurant.de",
            roleKey: "owner", roleName: "Inhaber", isMe: true
        ),
        KitchenLinkTeamMember(
            userID: "demo-2", email: "zweite@restaurant.de",
            roleKey: "owner", roleName: "Inhaber", isMe: false
        )
    ]))
    await model.load()

    // Zwei Inhaber: einer darf herunter.
    let other = model.members.first { $0.userID == "demo-2" }!
    await model.setRole(for: other, to: "service")
    #expect(model.members.first { $0.userID == "demo-2" }?.roleKey == "service")

    // Jetzt gibt es nur noch einen — und das ist der eigene Zugang.
    let me = model.members.first(where: \.isMe)!
    await model.setRole(for: me, to: "service")
    #expect(model.members.first(where: \.isMe)?.roleKey == "owner")
}

@MainActor
@Test func einNochNichtRegistrierterKollegeBekommtDieRichtigeAnsage() async {
    // Der häufigste Fall im Betrieb, und der einzige, der ohne Erklärung
    // ratlos macht: KitchenLink legt keine fremden Konten an.
    let model = makeModel(transport: KitchenLinkDemoTeamTransport())
    await model.load()

    model.inviteEmail = "gibtsnicht@restaurant.de"
    await model.invite()

    #expect(model.notice?.contains("noch kein Konto") == true)
    #expect(model.notice?.contains("selbst registrieren") == true)
    #expect(model.members.count == 4)
}

@MainActor
@Test func einRegistrierterKollegeWirdZugeordnet() async {
    let model = makeModel(transport: KitchenLinkDemoTeamTransport())
    await model.load()

    model.inviteEmail = "neu@restaurant.de"
    model.inviteRoleKey = "bar"
    #expect(model.canInvite)

    await model.invite()

    #expect(model.members.contains { $0.email == "neu@restaurant.de" && $0.roleKey == "bar" })
    #expect(model.inviteEmail.isEmpty)
}

@MainActor
@Test func ohneAtZeichenWirdNichtsVersucht() async {
    let model = makeModel(transport: KitchenLinkDemoTeamTransport())
    await model.load()

    model.inviteEmail = "kein-at-zeichen"
    #expect(model.canInvite == false)
}

@MainActor
@Test func jemandWirdAusDemTeamEntfernt() async {
    let model = makeModel(transport: KitchenLinkDemoTeamTransport())
    await model.load()

    let mira = model.members.first { $0.email == "mira@restaurant.de" }!
    await model.remove(mira)

    #expect(model.members.count == 3)
    #expect(model.members.contains { $0.email == "mira@restaurant.de" } == false)
}

@MainActor
@Test func derEigeneZugangWirdNichtEntfernt() async {
    let model = makeModel(transport: KitchenLinkDemoTeamTransport())
    await model.load()

    await model.remove(model.members.first(where: \.isMe)!)

    #expect(model.members.count == 4)
    #expect(model.notice?.contains("aussperren") == true)
}
