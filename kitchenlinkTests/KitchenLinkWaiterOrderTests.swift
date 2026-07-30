import Foundation
import Testing
@testable import kitchenlink

/// KL-TABLE-002: Bestellaufnahme durch den Kellner.
///
/// Der Kern dieser Tests ist die **Reihenfolge**: erst der dauerhafte lokale
/// Commit, dann die Bestätigung, dann die Cloud. Das ist die Zusage aus
/// `DECISIONS.md` (Local-First, 23. Juli 2026) — eine mündlich aufgegebene
/// Bestellung darf nicht verloren gehen, auch wenn die Cloud weg ist.

// MARK: - Helfer

private final class RecordingRepository: KitchenLinkRepository {
    private let base = LocalDemoRepository(
        defaults: UserDefaults(suiteName: "waiter-\(UUID().uuidString)")!
    )
    private(set) var created: [LiveOrderMessage] = []
    var failWith: Error?

    func loadVenueProfile(fallback: VenueProfile) -> VenueProfile {
        base.loadVenueProfile(fallback: fallback)
    }

    func saveVenueProfile(_ venue: VenueProfile) throws {
        try base.saveVenueProfile(venue)
    }

    func resolveQRCode(_ rawCode: String, venue: VenueProfile) -> ResolvedVenueContext? {
        base.resolveQRCode(rawCode, venue: venue)
    }

    func loadMenuSections(fallback: [MenuSectionData]) -> [MenuSectionData] {
        base.loadMenuSections(fallback: fallback)
    }

    func saveMenuSections(_ sections: [MenuSectionData]) throws {
        try base.saveMenuSections(sections)
    }

    func loadOrders() throws -> [LiveOrderMessage] { created }

    func loadOrder(orderID: String) throws -> LiveOrderMessage? {
        created.first { $0.id == orderID }
    }

    func createOrder(_ order: LiveOrderMessage) throws -> LiveOrderMessage {
        if let failWith { throw failWith }
        created.append(order)
        return order
    }

    func updateOrderStatus(orderID: String, to status: OrderLifecycleStatus) throws -> LiveOrderMessage? {
        nil
    }

    func clearOrders() throws { created = [] }
}

private enum WaiterTestError: Error, LocalizedError {
    case diskFull
    var errorDescription: String? { "Speicher voll" }
}

private func menuItem(
    id: String,
    name: String,
    priceCents: Int,
    kind: MenuItemKind = .food,
    available: Bool = true
) -> MenuItemData {
    MenuItemData(
        id: id,
        name: name,
        description: "",
        priceCents: priceCents,
        kind: kind,
        available: available
    )
}

private func sections() -> [MenuSectionData] {
    [
        MenuSectionData(
            id: "s1",
            title: "Küche",
            subtitle: "",
            kind: .food,
            items: [
                menuItem(id: "i1", name: "Kürbissuppe", priceCents: 690),
                menuItem(id: "i2", name: "Schnitzel", priceCents: 2180),
                menuItem(id: "i3", name: "Ausverkauft", priceCents: 500, available: false)
            ]
        ),
        MenuSectionData(
            id: "s2",
            title: "Nur Ausverkauftes",
            subtitle: "",
            kind: .food,
            items: [menuItem(id: "i4", name: "Weg", priceCents: 100, available: false)]
        )
    ]
}

private let testVenue = VenueProfile(
    id: "venue-1",
    name: "Alte Mühle",
    slug: "alte-muehle",
    supportedServiceModes: [.dineIn, .bar, .pickup],
    tables: []
)

private func table(id: String = "t1", label: String = "3") -> KitchenLinkVenueTable {
    KitchenLinkVenueTable(
        id: id,
        label: label,
        area: "Gastraum",
        sortOrder: 10,
        active: true,
        token: "tok"
    )
}

@MainActor
private func makeModel(
    repository: RecordingRepository,
    syncResult: Bool = true,
    syncCalls: (@Sendable () -> Void)? = nil
) -> KitchenLinkWaiterOrderModel {
    KitchenLinkWaiterOrderModel(
        repository: repository,
        venue: testVenue,
        sections: sections(),
        syncCloud: {
            syncCalls?()
            return syncResult
        }
    )
}

// MARK: - Aufnahme

@MainActor
@Test func nurVerfuegbareArtikelSindAufnehmbar() {
    let model = makeModel(repository: RecordingRepository())

    // Der ausverkaufte Artikel fällt raus, der reine Ausverkauft-Bereich ganz.
    #expect(model.orderableSections.count == 1)
    #expect(model.orderableSections.first?.items.map(\.id) == ["i1", "i2"])
}

@MainActor
@Test func mengenUndSummeFolgenDenTaps() {
    let model = makeModel(repository: RecordingRepository())
    let suppe = sections()[0].items[0]
    let schnitzel = sections()[0].items[1]

    model.increment(suppe)
    model.increment(suppe)
    model.increment(schnitzel)

    #expect(model.quantity(for: suppe) == 2)
    #expect(model.itemCount == 3)
    #expect(model.totalCents == 690 * 2 + 2180)

    model.decrement(suppe)
    #expect(model.quantity(for: suppe) == 1)
    model.decrement(suppe)
    #expect(model.quantity(for: suppe) == 0)
    // Auf null heißt raus, nicht negativ.
    model.decrement(suppe)
    #expect(model.quantity(for: suppe) == 0)
    #expect(model.totalCents == 2180)
}

@MainActor
@Test func vorOrtBrauchtEinenTischTheseUndAbholungNicht() {
    let model = makeModel(repository: RecordingRepository())
    model.increment(sections()[0].items[0])

    #expect(model.requiresTable)
    #expect(!model.canPlace)
    #expect(model.placementBlockedReason == "Bitte einen Tisch wählen.")

    model.serviceMode = .pickup
    #expect(!model.requiresTable)
    #expect(model.canPlace)

    model.serviceMode = .dineIn
    model.selectedTable = table()
    #expect(model.canPlace)
}

@MainActor
@Test func leereBestellungWirdNichtAngenommen() async {
    let repository = RecordingRepository()
    let model = makeModel(repository: repository)
    model.selectedTable = table()

    await model.place()

    #expect(repository.created.isEmpty)
    #expect(model.phase == .failed("Noch keine Position aufgenommen."))
}

// MARK: - Annahme

@MainActor
@Test func angenommeneBestellungTraegtTischPositionenUndSumme() async {
    let repository = RecordingRepository()
    let model = makeModel(repository: repository)
    model.selectedTable = table(id: "t7", label: "7")
    model.customerNote = "  ohne Zwiebeln  "
    model.increment(sections()[0].items[1])
    model.increment(sections()[0].items[0])
    model.increment(sections()[0].items[0])

    await model.place()

    let order = try! #require(repository.created.first)
    #expect(order.tableID == "t7")
    #expect(order.tableLabel == "7")
    #expect(order.serviceMode == .dineIn)
    #expect(order.status == .pending)
    #expect(order.customerNote == "ohne Zwiebeln")
    #expect(order.totalCents == 690 * 2 + 2180)
    // Stabile Reihenfolge nach Name, damit die Küche zweimal dasselbe sieht.
    #expect(order.items.map(\.name) == ["Kürbissuppe", "Schnitzel"])
    #expect(order.items.first?.quantity == 2)
    #expect(order.operatorContextLine.contains("Tisch 7"))
}

@MainActor
@Test func bestaetigungKommtErstNachDemDauerhaftenSchreiben() async {
    let repository = RecordingRepository()
    var syncCalls = 0
    let model = KitchenLinkWaiterOrderModel(
        repository: repository,
        venue: testVenue,
        sections: sections(),
        syncCloud: {
            // Die Cloud wird erst gefragt, wenn lokal bereits geschrieben ist.
            #expect(repository.created.count == 1)
            syncCalls += 1
            return true
        }
    )
    model.selectedTable = table()
    model.increment(sections()[0].items[0])

    await model.place()

    #expect(syncCalls == 1)
    if case .placed(_, let synced) = model.phase {
        #expect(synced)
    } else {
        Issue.record("Erwartet: bestätigte Bestellung, war \(model.phase)")
    }
    // Nach der Annahme ist der Block leer für die nächste Bestellung.
    #expect(model.isEmpty)
}

@MainActor
@Test func ohneCloudGiltDieBestellungTrotzdemAlsAngenommen() async {
    let repository = RecordingRepository()
    let model = makeModel(repository: repository, syncResult: false)
    model.serviceMode = .bar
    model.increment(sections()[0].items[0])

    await model.place()

    #expect(repository.created.count == 1)
    if case .placed(_, let synced) = model.phase {
        #expect(!synced)
    } else {
        Issue.record("Ohne Cloud muss die Bestellung trotzdem angenommen sein")
    }
}

@MainActor
@Test func scheiterndesSchreibenGibtKeineBestaetigungUndBehaeltDieEingabe() async {
    let repository = RecordingRepository()
    repository.failWith = WaiterTestError.diskFull
    var syncCalls = 0
    let model = makeModel(repository: repository, syncCalls: { syncCalls += 1 })
    model.selectedTable = table()
    model.increment(sections()[0].items[0])

    await model.place()

    #expect(repository.created.isEmpty)
    #expect(syncCalls == 0, "Ohne lokalen Commit darf nichts in die Cloud gehen")
    #expect(model.phase == .failed("Speicher voll"))
    // Der Kellner soll nicht neu tippen müssen.
    #expect(model.itemCount == 1)
}

@MainActor
@Test func aenderungNachDerAnnahmeVerwirftDieAlteBestaetigung() async {
    let model = makeModel(repository: RecordingRepository())
    model.selectedTable = table()
    model.increment(sections()[0].items[0])
    await model.place()

    model.increment(sections()[0].items[1])

    #expect(model.phase == .composing)
}
