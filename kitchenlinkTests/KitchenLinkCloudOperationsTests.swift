import Foundation
import Testing
@testable import kitchenlink

/// KL-CLOUD-001: Cloud-Bestellschleife auf der Betreiberseite.
///
/// Getestet wird gegen einen Transport-Spy (kein Netzwerk): Wire-Mapping in
/// die bestehende `LiveOrderMessage`-Domäne, Sitzungserneuerung bei 401,
/// Abmeldung bei totem Refresh-Token, Status-RPC-Routing, Heartbeat-Inhalt
/// und die Zusammenführung von Online- und lokalen Bestellungen.

actor KitchenLinkCloudTransportSpy: KitchenLinkCloudTransport {
    var venue: KitchenLinkCloudVenue?
    var wireOrders: [KitchenLinkCloudWireOrder]
    var failNextLoadUnauthorized = false
    var refreshError: KitchenLinkCloudServiceError?
    var refreshedSession = KitchenLinkCloudSession(
        accessToken: "at2",
        refreshToken: "rt2",
        userID: "user-1",
        expiresAt: .distantFuture
    )

    private(set) var refreshCalls = 0
    private(set) var statusCalls: [(orderID: String, target: OrderLifecycleStatus)] = []
    private(set) var presenceCalls: [(slug: String, deviceID: String, url: String?)] = []

    init(
        venue: KitchenLinkCloudVenue? = KitchenLinkCloudVenue(id: "venue-1", name: "Gasthaus Alte Mühle"),
        wireOrders: [KitchenLinkCloudWireOrder] = []
    ) {
        self.venue = venue
        self.wireOrders = wireOrders
    }

    func setFailNextLoadUnauthorized(_ value: Bool) {
        failNextLoadUnauthorized = value
    }

    func setRefreshError(_ error: KitchenLinkCloudServiceError?) {
        refreshError = error
    }

    func signIn(
        config: KitchenLinkCloudConfig,
        email: String,
        password: String
    ) async throws -> KitchenLinkCloudSession {
        KitchenLinkCloudSession(
            accessToken: "at1",
            refreshToken: "rt1",
            userID: "user-1",
            expiresAt: .distantFuture
        )
    }

    func refresh(
        config: KitchenLinkCloudConfig,
        refreshToken: String
    ) async throws -> KitchenLinkCloudSession {
        refreshCalls += 1
        if let refreshError {
            throw refreshError
        }
        return refreshedSession
    }

    func resolveVenue(
        config: KitchenLinkCloudConfig,
        slug: String
    ) async throws -> KitchenLinkCloudVenue? {
        venue
    }

    func loadOrders(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueID: String
    ) async throws -> [KitchenLinkCloudWireOrder] {
        if failNextLoadUnauthorized {
            failNextLoadUnauthorized = false
            throw KitchenLinkCloudServiceError.unauthorized
        }
        return wireOrders
    }

    func updateStatus(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        orderID: String,
        targetStatus: OrderLifecycleStatus
    ) async throws -> KitchenLinkCloudStatusReceipt {
        statusCalls.append((orderID, targetStatus))
        if let index = wireOrders.firstIndex(where: { $0.id == orderID }) {
            let order = wireOrders[index]
            wireOrders[index] = KitchenLinkCloudWireOrder(
                id: order.id,
                createdAt: order.createdAt,
                status: targetStatus.rawValue,
                totalCents: order.totalCents,
                currency: order.currency,
                serviceMode: order.serviceMode,
                customerNote: order.customerNote,
                sourceDevice: order.sourceDevice,
                items: order.items
            )
        }
        return KitchenLinkCloudStatusReceipt(
            orderID: orderID,
            status: targetStatus.rawValue,
            replayed: false
        )
    }

    func upsertPresence(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        deviceID: String,
        localGuestURL: String?
    ) async throws {
        presenceCalls.append((venueSlug, deviceID, localGuestURL))
    }
}

@MainActor
struct KitchenLinkCloudOperationsTests {
    private func makeDefaults() -> UserDefaults {
        let suite = "cloud-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    /// Nur eine gespeicherte Sitzung wird geseedet — die Verbindungsdaten
    /// (URL/Anon-Key/Venue) kommen aus dem eingebackenen Sandbox-Standard.
    private func seedCredentials(into defaults: UserDefaults) {
        let store = KitchenLinkCloudCredentialStore(defaults: defaults)
        store.save(session: KitchenLinkCloudSession(
            accessToken: "at1",
            refreshToken: "rt1",
            userID: "user-1",
            expiresAt: .distantFuture
        ))
    }

    private func wireOrder(
        id: String = "11111111-2222-3333-4444-555555555555",
        createdAt: String = "2026-07-19T10:15:00.123456+00:00",
        status: String = "pending",
        note: String = "",
        kind: String = "food"
    ) -> KitchenLinkCloudWireOrder {
        KitchenLinkCloudWireOrder(
            id: id,
            createdAt: createdAt,
            status: status,
            totalCents: 1840,
            currency: "EUR",
            serviceMode: "dine_in",
            customerNote: note,
            sourceDevice: "guest_web",
            items: [
                KitchenLinkCloudWireOrderItem(
                    id: "item-1",
                    name: "Kürbissuppe",
                    quantity: 2,
                    unitPriceCents: 690,
                    kind: kind
                )
            ]
        )
    }

    private func liveOrder(
        id: String,
        status: OrderLifecycleStatus,
        createdAt: Date
    ) -> LiveOrderMessage {
        LiveOrderMessage(
            id: id,
            createdAt: createdAt,
            sourceDevice: "Test",
            venueID: "venue-1",
            venueName: "Test",
            serviceMode: .dineIn,
            tableID: nil,
            tableLabel: nil,
            customerNote: "",
            items: [],
            totalCents: 100,
            status: status
        )
    }

    // MARK: Wire-Mapping

    @Test func wireOrderMapsToLiveOrder() {
        let order = wireOrder(status: "preparing", note: "ohne Zwiebeln", kind: "drink")
        let live = order.liveOrder(venueID: "venue-1", venueName: "Gasthaus Alte Mühle")

        #expect(live != nil)
        #expect(live?.status == .preparing)
        #expect(live?.venueName == "Gasthaus Alte Mühle")
        #expect(live?.serviceMode == .dineIn)
        #expect(live?.customerNote == "ohne Zwiebeln")
        #expect(live?.totalCents == 1840)
        #expect(live?.items.count == 1)
        #expect(live?.items.first?.kind == .drink)
        #expect(live?.sourceDevice.hasPrefix("Online · #") == true)
    }

    @Test func wireOrderWithUnknownStatusOrTimestampIsDropped() {
        #expect(wireOrder(status: "explodiert")
            .liveOrder(venueID: "v", venueName: "V") == nil)
        #expect(wireOrder(createdAt: "gestern mittag")
            .liveOrder(venueID: "v", venueName: "V") == nil)
    }

    @Test func timestampParsesWithAndWithoutFractionalSeconds() {
        #expect(KitchenLinkCloudTimestamp.parse("2026-07-19T10:15:00.123456+00:00") != nil)
        #expect(KitchenLinkCloudTimestamp.parse("2026-07-19T10:15:00+00:00") != nil)
        #expect(KitchenLinkCloudTimestamp.parse("2026-07-19T10:15:00Z") != nil)
        #expect(KitchenLinkCloudTimestamp.parse("kein datum") == nil)
    }

    // MARK: Laden und Status

    @Test func refreshOrdersPopulatesAndConnects() async {
        let defaults = makeDefaults()
        seedCredentials(into: defaults)
        let spy = KitchenLinkCloudTransportSpy(wireOrders: [wireOrder()])
        let model = KitchenLinkCloudOperationsModel(transport: spy, defaults: defaults)

        await model.refreshOrders()

        #expect(model.connectionState == .connected)
        #expect(model.venueName == "Gasthaus Alte Mühle")
        #expect(model.orders.count == 1)
        #expect(model.orders.first?.status == .pending)
        #expect(model.containsOrder(id: "11111111-2222-3333-4444-555555555555"))
    }

    @Test func updateStatusRoutesThroughRpcAndRefreshes() async {
        let defaults = makeDefaults()
        seedCredentials(into: defaults)
        let orderID = "11111111-2222-3333-4444-555555555555"
        let spy = KitchenLinkCloudTransportSpy(wireOrders: [wireOrder(id: orderID)])
        let model = KitchenLinkCloudOperationsModel(transport: spy, defaults: defaults)
        await model.refreshOrders()

        let success = await model.update(
            order: model.orders[0],
            to: .ready
        )

        #expect(success)
        let calls = await spy.statusCalls
        #expect(calls.count == 1)
        #expect(calls.first?.orderID == orderID)
        #expect(calls.first?.target == .ready)
        // Der Spy hat den Status mutiert; der anschließende Refresh zeigt ihn.
        #expect(model.orders.first?.status == .ready)
    }

    @Test func unauthorizedRefreshesSessionExactlyOnceAndRetries() async {
        let defaults = makeDefaults()
        seedCredentials(into: defaults)
        let spy = KitchenLinkCloudTransportSpy(wireOrders: [wireOrder()])
        await spy.setFailNextLoadUnauthorized(true)
        let model = KitchenLinkCloudOperationsModel(transport: spy, defaults: defaults)

        await model.refreshOrders()

        #expect(model.connectionState == .connected)
        #expect(model.orders.count == 1)
        let refreshCalls = await spy.refreshCalls
        #expect(refreshCalls == 1)
        let stored = KitchenLinkCloudCredentialStore(defaults: defaults).loadSession()
        #expect(stored?.accessToken == "at2")
    }

    @Test func deadRefreshTokenSignsOutAndClearsSession() async {
        let defaults = makeDefaults()
        seedCredentials(into: defaults)
        let spy = KitchenLinkCloudTransportSpy(wireOrders: [wireOrder()])
        await spy.setFailNextLoadUnauthorized(true)
        // GoTrue meldet ein totes Refresh-Token als 400er-Serverfehler.
        await spy.setRefreshError(.server(status: 400, message: "Invalid Refresh Token"))
        let model = KitchenLinkCloudOperationsModel(transport: spy, defaults: defaults)

        await model.refreshOrders()

        #expect(model.connectionState == .signedOut)
        #expect(KitchenLinkCloudCredentialStore(defaults: defaults).loadSession() == nil)
    }

    @Test func missingVenueReportsUnreachable() async {
        let defaults = makeDefaults()
        seedCredentials(into: defaults)
        let spy = KitchenLinkCloudTransportSpy(venue: nil)
        let model = KitchenLinkCloudOperationsModel(transport: spy, defaults: defaults)

        await model.refreshOrders()

        guard case .unreachable(let message) = model.connectionState else {
            Issue.record("erwartet unreachable, war \(model.connectionState)")
            return
        }
        #expect(message.contains("alte-muehle"))
    }

    @Test func signInRejectsEmptyCredentials() async {
        let defaults = makeDefaults()
        let spy = KitchenLinkCloudTransportSpy()
        let model = KitchenLinkCloudOperationsModel(transport: spy, defaults: defaults)

        let success = await model.signIn(email: "  ", password: "")

        #expect(!success)
        guard case .unreachable = model.connectionState else {
            Issue.record("erwartet unreachable, war \(model.connectionState)")
            return
        }
    }

    @Test func signInStoresSessionAndConnects() async {
        let defaults = makeDefaults()
        let spy = KitchenLinkCloudTransportSpy(wireOrders: [wireOrder()])
        let model = KitchenLinkCloudOperationsModel(transport: spy, defaults: defaults)

        let success = await model.signIn(email: "op@example.com", password: "geheim")

        #expect(success)
        // Ohne technische Felder: eine gespeicherte Sitzung reicht, damit sich
        // die App beim nächsten Start von selbst wieder verbindet.
        #expect(KitchenLinkCloudCredentialStore(defaults: defaults).loadSession() != nil)
    }

    @Test func heartbeatPublishesAndClearsLocalGuestURL() async {
        let defaults = makeDefaults()
        seedCredentials(into: defaults)
        let spy = KitchenLinkCloudTransportSpy()
        let model = KitchenLinkCloudOperationsModel(transport: spy, defaults: defaults)

        model.setLocalGuestURL(URL(string: "http://192.168.178.30:52123"))
        await model.sendHeartbeat()

        var calls = await spy.presenceCalls
        #expect(calls.last?.slug == "alte-muehle")
        #expect(calls.last?.url == "http://192.168.178.30:52123")
        #expect(calls.last?.deviceID.isEmpty == false)

        model.setLocalGuestURL(nil)
        await model.sendHeartbeat()

        calls = await spy.presenceCalls
        #expect(calls.last?.url == nil)
    }

    // MARK: Zusammenführung

    @Test func kitchenMergeCombinesLocalPreparingWithOpenOnlineOrders() {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let local = [
            liveOrder(id: "local-prep", status: .preparing, createdAt: base.addingTimeInterval(30)),
            liveOrder(id: "local-ready", status: .ready, createdAt: base)
        ]
        let online = [
            liveOrder(id: "online-pending", status: .pending, createdAt: base.addingTimeInterval(10)),
            liveOrder(id: "online-accepted", status: .accepted, createdAt: base.addingTimeInterval(50)),
            liveOrder(id: "online-served", status: .served, createdAt: base)
        ]

        let kitchen = KitchenLinkServiceOrderMerge.kitchenOrders(local: local, online: online)

        #expect(kitchen.map(\.id) == ["online-pending", "local-prep", "online-accepted"])
    }

    @Test func waiterMergeShowsReadyFromBothSources() {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let local = [
            liveOrder(id: "local-ready", status: .ready, createdAt: base.addingTimeInterval(20)),
            liveOrder(id: "local-prep", status: .preparing, createdAt: base)
        ]
        let online = [
            liveOrder(id: "online-ready", status: .ready, createdAt: base.addingTimeInterval(5)),
            liveOrder(id: "online-pending", status: .pending, createdAt: base)
        ]

        let waiter = KitchenLinkServiceOrderMerge.waiterOrders(local: local, online: online)

        #expect(waiter.map(\.id) == ["online-ready", "local-ready"])
    }
}
