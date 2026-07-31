import Foundation
import Testing
@testable import kitchenlink

/// KL-STATION-001 und KL-ORDER-001: Stationen und Annahmeregel.
///
/// Geprüft wird die Seite, die im Gerät entschieden wird: welche Station eine
/// Position bekommt, welche Bestellung eine Station überhaupt sieht, und wann
/// eine Bestellung auf Bestätigung wartet.
///
/// Dass eine Bestellung erst `ready` wird, wenn **alle** Stationen fertig sind,
/// entscheidet die Datenbank — `scripts/tests/stations-and-confirmation.sql`
/// prüft das gegen echtes PostgreSQL.

private func line(
    id: String,
    name: String,
    kind: MenuItemKind,
    readyAt: Date? = nil
) -> LiveOrderLine {
    LiveOrderLine(
        id: id,
        name: name,
        quantity: 1,
        unitPriceCents: 500,
        kind: kind,
        readyAt: readyAt
    )
}

private func order(
    id: String = "o1",
    status: OrderLifecycleStatus = .pending,
    serviceMode: ServiceMode? = .dineIn,
    items: [LiveOrderLine]
) -> LiveOrderMessage {
    LiveOrderMessage(
        id: id,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        sourceDevice: "Test",
        venueID: "v1",
        venueName: "Venue",
        serviceMode: serviceMode,
        tableID: nil,
        tableLabel: nil,
        customerNote: "",
        items: items,
        totalCents: items.reduce(0) { $0 + $1.lineTotalCents },
        status: status
    )
}

// MARK: - Stationszuordnung

@Test func speisenGehenInDieKuecheGetraenkeAnDieBar() {
    #expect(KitchenLinkStation(kind: .food) == .kitchen)
    #expect(KitchenLinkStation(kind: .drink) == .bar)
    #expect(line(id: "l1", name: "Schnitzel", kind: .food).station == .kitchen)
    #expect(line(id: "l2", name: "Radler", kind: .drink).station == .bar)
    #expect(KitchenLinkStation.kitchen.title == "Küche")
    #expect(KitchenLinkStation.bar.title == "Bar")
}

@Test func einePositionOhneFreigabeIstNochNichtFertig() {
    #expect(line(id: "l1", name: "Suppe", kind: .food).isReady == false)
    #expect(line(id: "l1", name: "Suppe", kind: .food, readyAt: Date()).isReady)
}

@Test func aeltereSchnappschuesseBleibenLesbar() throws {
    // Ohne `ready_at` — so liegen bestehende Bestellungen im Ereignisprotokoll.
    let json = """
    {"id":"l1","name":"Suppe","quantity":2,"unitPriceCents":690,"kind":"food"}
    """
    let decoded = try JSONDecoder().decode(LiveOrderLine.self, from: Data(json.utf8))
    #expect(decoded.readyAt == nil)
    #expect(decoded.station == .kitchen)
    #expect(decoded.lineTotalCents == 1380)
}

// MARK: - Stationsantwort

@Test func stationsbelegNenntDieNochOffenenStationen() throws {
    let json = """
    {"order_id":"11111111-2222-3333-4444-555555555555","station":"kitchen",
     "items_marked":2,"open_stations":["bar"],"order_ready":false}
    """
    let receipt = try KitchenLinkStationReceipt.decode(Data(json.utf8))

    #expect(receipt.station == .kitchen)
    #expect(receipt.itemsMarked == 2)
    #expect(receipt.openStations == [.bar])
    #expect(receipt.orderReady == false)
}

@Test func stationsbelegOhneOffeneStationMeldetBereit() throws {
    let json = """
    {"order_id":"o1","station":"bar","items_marked":1,
     "open_stations":[],"order_ready":true}
    """
    let receipt = try KitchenLinkStationReceipt.decode(Data(json.utf8))
    #expect(receipt.openStations.isEmpty)
    #expect(receipt.orderReady)
}

// MARK: - Annahmeregel

@Test func ohneRegelLaeuftAllesDurch() {
    let pending = order(items: [line(id: "l1", name: "Suppe", kind: .food)])

    #expect(KitchenLinkOrderAcceptance.needsConfirmation(
        order: pending, confirmationChannels: []
    ) == false)
    #expect(KitchenLinkOrderAcceptance.stationVisible(
        orders: [pending], confirmationChannels: []
    ).count == 1)
    #expect(KitchenLinkOrderAcceptance.awaitingConfirmation(
        orders: [pending], confirmationChannels: []
    ).isEmpty)
}

@Test func dieRegelGiltNurFuerIhrenKanal() {
    let pickup = order(id: "o1", serviceMode: .pickup, items: [
        line(id: "l1", name: "Suppe", kind: .food)
    ])
    let dineIn = order(id: "o2", serviceMode: .dineIn, items: [
        line(id: "l2", name: "Suppe", kind: .food)
    ])

    let channels: [ServiceMode] = [.pickup]
    #expect(KitchenLinkOrderAcceptance.needsConfirmation(order: pickup, confirmationChannels: channels))
    #expect(KitchenLinkOrderAcceptance.needsConfirmation(order: dineIn, confirmationChannels: channels) == false)

    let visible = KitchenLinkOrderAcceptance.stationVisible(
        orders: [pickup, dineIn], confirmationChannels: channels
    )
    #expect(visible.map(\.id) == ["o2"], "Die Abholung darf die Station noch nicht erreichen")

    let waiting = KitchenLinkOrderAcceptance.awaitingConfirmation(
        orders: [pickup, dineIn], confirmationChannels: channels
    )
    #expect(waiting.map(\.id) == ["o1"])
}

@Test func nachDerAnnahmeWartetNichtsMehr() {
    let accepted = order(status: .accepted, serviceMode: .pickup, items: [
        line(id: "l1", name: "Suppe", kind: .food)
    ])
    #expect(KitchenLinkOrderAcceptance.needsConfirmation(
        order: accepted, confirmationChannels: [.pickup]
    ) == false)
}

@Test func ohneErkennbarenKanalWirdImZweifelBestaetigt() {
    let unknownChannel = order(serviceMode: nil, items: [
        line(id: "l1", name: "Suppe", kind: .food)
    ])
    // Hat der Betrieb überhaupt eine Bestätigungspflicht, wird bestätigt.
    #expect(KitchenLinkOrderAcceptance.needsConfirmation(
        order: unknownChannel, confirmationChannels: [.pickup]
    ))
    // Ohne Regel bleibt es beim Durchlaufen.
    #expect(KitchenLinkOrderAcceptance.needsConfirmation(
        order: unknownChannel, confirmationChannels: []
    ) == false)
}

// MARK: - Zusammenspiel mit der Service-Liste

@Test func stationssichtLaesstUnbestaetigteBestellungenAus() {
    let waiting = order(id: "o1", serviceMode: .pickup, items: [
        line(id: "l1", name: "Suppe", kind: .food)
    ])
    let running = order(id: "o2", status: .preparing, serviceMode: .dineIn, items: [
        line(id: "l2", name: "Schnitzel", kind: .food)
    ])

    let kitchen = KitchenLinkServiceOrderMerge.kitchenOrders(
        local: [], online: [waiting, running]
    )
    #expect(kitchen.count == 2, "Beide sind grundsätzlich in Produktion")

    let visible = KitchenLinkOrderAcceptance.stationVisible(
        orders: kitchen, confirmationChannels: [.pickup]
    )
    #expect(visible.map(\.id) == ["o2"])
}
