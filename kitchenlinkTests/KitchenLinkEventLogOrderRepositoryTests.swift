import Foundation
import Testing
@testable import KitchenLinkEventLog
@testable import kitchenlink

/// A test spy that records every `createOrder` invocation and returns a
/// configurable result.
private actor CloudTransportSpy: KitchenLinkCloudTransport {
    struct CreateOrderCall: Sendable, Equatable {
        let id: String
        let totalCents: Int
        let sourceDevice: String
        let serviceMode: String
    }

    private(set) var createOrderCalls: [CreateOrderCall] = []
    /// KL-TABLE-002: der Tisch muss den Weg durch die Outbox überstehen.
    private(set) var lastTableID: String?
    private var createOrderResult: Bool = true

    func setCreateOrderResult(_ value: Bool) {
        createOrderResult = value
    }

    func createOrder(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        venueSlug: String,
        id: String,
        createdAt: Date,
        sourceDevice: String,
        totalCents: Int,
        serviceMode: String,
        customerNote: String,
        itemsJSON: Data,
        tableID: String?
    ) async throws -> Bool {
        lastTableID = tableID
        createOrderCalls.append(CreateOrderCall(id: id, totalCents: totalCents, sourceDevice: sourceDevice, serviceMode: serviceMode))
        return createOrderResult
    }

    func signIn(config: KitchenLinkCloudConfig, email: String, password: String) async throws -> KitchenLinkCloudSession {
        KitchenLinkCloudSession(accessToken: "t", refreshToken: "r", userID: "u", expiresAt: .distantFuture)
    }
    func refresh(config: KitchenLinkCloudConfig, refreshToken: String) async throws -> KitchenLinkCloudSession {
        KitchenLinkCloudSession(accessToken: "t", refreshToken: "r", userID: "u", expiresAt: .distantFuture)
    }
    func resolveVenue(config: KitchenLinkCloudConfig, slug: String) async throws -> KitchenLinkCloudVenue? { nil }
    func loadOrders(config: KitchenLinkCloudConfig, session: KitchenLinkCloudSession, venueID: String) async throws -> [KitchenLinkCloudWireOrder] { [] }
    func updateStatus(config: KitchenLinkCloudConfig, session: KitchenLinkCloudSession, orderID: String, targetStatus: OrderLifecycleStatus) async throws -> KitchenLinkCloudStatusReceipt {
        KitchenLinkCloudStatusReceipt(orderID: orderID, status: targetStatus.rawValue, replayed: false)
    }
    func upsertPresence(config: KitchenLinkCloudConfig, session: KitchenLinkCloudSession, venueSlug: String, deviceID: String, localGuestURL: String?) async throws {}
}

// MARK: - CloudOutboxTransport

struct CloudOutboxTransportTests {
    private let config = KitchenLinkCloudConfig.sandboxDefault
    private let session = KitchenLinkCloudSession(accessToken: "at", refreshToken: "rt", userID: "uid", expiresAt: .distantFuture)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private func makeClaim(eventType: String, payload: Data) -> Outbox.Claim {
        Outbox.Claim(
            eventSeq: 1,
            target: OutboxTarget(rawValue: "cloud"),
            leaseToken: "lt-1",
            leaseExpiresMs: 9999999999999,
            attempts: 1,
            event: EventRecord(
                eventID: EventID(rawValue: "e1"),
                localSeq: 1,
                venueID: VenueID(rawValue: "v1"),
                aggregateID: AggregateID(rawValue: "a1"),
                aggregateType: "order",
                aggregateRev: 1,
                eventType: eventType,
                payloadVersion: 1,
                payload: payload,
                requestFingerprint: "fp",
                idempotencyKey: IdempotencyKey(rawValue: "ik1"),
                deviceID: DeviceID(rawValue: "d1"),
                occurredAtMs: 1_000_000,
                loggedAtMs: 1_000_000
            )
        )
    }

    private func placedPayload(order: LiveOrderMessage) throws -> Data {
        struct PlacedEnvelope: Codable {
            let status: String
            let snapshot: Data
        }
        let snapshot = try encoder.encode(order)
        return try encoder.encode(PlacedEnvelope(status: "pending", snapshot: snapshot))
    }

    @Test func unknownEventType() async throws {
        let spy = CloudTransportSpy()
        let transport = CloudOutboxTransport(config: config, session: session, cloudTransport: spy)
        let claim = makeClaim(eventType: "garbage", payload: Data())
        let result = try await transport.deliver(claim)
        if case .failed(let reason) = result {
            #expect(reason.contains("unknown event type"))
        } else {
            Issue.record("expected .failed, got \(result)")
        }
    }

    @Test func malformedPayload() async throws {
        let spy = CloudTransportSpy()
        let transport = CloudOutboxTransport(config: config, session: session, cloudTransport: spy)
        let claim = makeClaim(eventType: "operator_order_placed", payload: Data("garbage".utf8))
        let result = try await transport.deliver(claim)
        if case .failed(let reason) = result {
            #expect(reason.contains("malformed"))
        } else {
            Issue.record("expected .failed, got \(result)")
        }
    }

    @Test func successfulPlacedDelivery() async throws {
        let spy = CloudTransportSpy()
        let transport = CloudOutboxTransport(config: config, session: session, cloudTransport: spy)
        let order = LiveOrderMessage(
            id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
            createdAt: Date(timeIntervalSince1970: 1_720_000_000),
            sourceDevice: "Test",
            venueID: "v1",
            venueName: "Venue",
            serviceMode: .dineIn,
            tableID: nil,
            tableLabel: nil,
            customerNote: "Bitte kalt",
            items: [LiveOrderLine(id: "li1", name: "Cola", quantity: 2, unitPriceCents: 350, kind: .drink)],
            totalCents: 700,
            status: .pending
        )
        let payload = try placedPayload(order: order)
        let claim = makeClaim(eventType: "operator_order_placed", payload: payload)
        let result = try await transport.deliver(claim)
        guard case .acknowledged(let remoteToken) = result else {
            Issue.record("expected .acknowledged, got \(result)")
            return
        }
        #expect(remoteToken == order.id)
        let calls = await spy.createOrderCalls
        #expect(calls.count == 1)
        #expect(calls.first?.id == order.id)
        #expect(calls.first?.totalCents == 700)
        #expect(calls.first?.sourceDevice == "ios-waiter")
        #expect(calls.first?.serviceMode == "dine_in")
    }

    /// KL-TABLE-002: Der Tisch der Kellnerbestellung muss den Weg durch das
    /// Ereignisprotokoll und die Outbox überstehen — sonst käme sie in der
    /// Cloud ohne Platz an und die Küche wüsste nicht, wohin damit.
    @Test func placedDeliveryCarriesTheTable() async throws {
        let spy = CloudTransportSpy()
        let transport = CloudOutboxTransport(config: config, session: session, cloudTransport: spy)
        let order = LiveOrderMessage(
            id: "b1b2c3d4-e5f6-7890-abcd-ef1234567890",
            createdAt: Date(timeIntervalSince1970: 1_720_000_000),
            sourceDevice: "Kellner",
            venueID: "v1",
            venueName: "Venue",
            serviceMode: .dineIn,
            tableID: "table-7",
            tableLabel: "7",
            customerNote: "",
            items: [LiveOrderLine(id: "li1", name: "Suppe", quantity: 1, unitPriceCents: 690, kind: .food)],
            totalCents: 690,
            status: .pending
        )
        let payload = try placedPayload(order: order)
        let claim = makeClaim(eventType: "operator_order_placed", payload: payload)

        let result = try await transport.deliver(claim)

        guard case .acknowledged = result else {
            Issue.record("expected .acknowledged, got \(result)")
            return
        }
        #expect(await spy.lastTableID == "table-7")
    }

    @Test func placedDeliveryTransportError() async throws {
        let spy = CloudTransportSpy()
        await spy.setCreateOrderResult(false)
        let transport = CloudOutboxTransport(config: config, session: session, cloudTransport: spy)
        let order = LiveOrderMessage(
            id: "b2c3d4e5-f6a7-8901-bcde-f12345678901",
            createdAt: Date(),
            sourceDevice: "Test",
            venueID: "v1",
            venueName: "V",
            serviceMode: nil,
            tableID: nil,
            tableLabel: nil,
            customerNote: "",
            items: [LiveOrderLine(id: "li1", name: "Wasser", quantity: 1, unitPriceCents: 200, kind: .drink)],
            totalCents: 200,
            status: .pending
        )
        let payload = try placedPayload(order: order)
        let claim = makeClaim(eventType: "operator_order_placed", payload: payload)
        let result = try await transport.deliver(claim)
        if case .failed(let reason) = result {
            #expect(reason.contains("RPC returned false"))
        } else {
            Issue.record("expected .failed when RPC returns false, got \(result)")
        }
    }
}

// MARK: - drainCloudOutbox integration

extension KitchenLinkEventLogOrderRepositoryTests {
    @Test func drainOutboxAcknowledgesPlacedOrder() async throws {
        let spy = CloudTransportSpy()
        let repo = try EventLogOrderRepository.makeForTesting(base: LocalDemoRepository(), databasePath: try makePath())
        let order = makeOrder(note: "Outbox-Test")
        _ = try repo.createOrder(order)
        // createOrder appends a placed event + cloud outbox row.
        let config = KitchenLinkCloudConfig.sandboxDefault
        let session = KitchenLinkCloudSession(accessToken: "at", refreshToken: "rt", userID: "u", expiresAt: .distantFuture)
        let acked = try await repo.drainCloudOutbox(config: config, session: session, cloudTransport: spy)
        #expect(acked > 0)
        let calls = await spy.createOrderCalls
        #expect(calls.count == 1)
        #expect(calls.first?.id == order.id)
    }
}

/// KL-OFFLINE (local-first): the durable order repository must keep orders and
/// status changes across a process restart, so a single device never loses an
/// order when the app is killed or the cloud is unavailable. The demo repository
/// remains covered separately by `KitchenLinkRepositoryTests`.
struct KitchenLinkEventLogOrderRepositoryTests {
    private func makePath() throws -> String {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kitchenlink-order-repo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("orders.sqlite").path
    }

    private func makeOrder(
        id: String = UUID().uuidString.lowercased(),
        note: String = "Ohne Eis"
    ) -> LiveOrderMessage {
        LiveOrderMessage(
            id: id,
            createdAt: .now,
            sourceDevice: "Test-Gerät",
            venueID: "venue-x",
            venueName: "Test Venue",
            serviceMode: .dineIn,
            tableID: "table-1",
            tableLabel: "A1",
            customerNote: note,
            items: [
                LiveOrderLine(id: "l1", name: "Hauslimonade", quantity: 2, unitPriceCents: 450, kind: .drink)
            ],
            totalCents: 900,
            status: .pending
        )
    }

    @Test func createPersistsOrderAsPending() throws {
        let repo = try EventLogOrderRepository.makeForTesting(base: LocalDemoRepository(), databasePath: try makePath())
        let created = try repo.createOrder(makeOrder(note: "Extra scharf"))

        #expect(created.status == .pending)
        let loaded = try repo.loadOrders()
        #expect(loaded.count == 1)
        #expect(loaded.first?.id == created.id)
        #expect(loaded.first?.customerNote == "Extra scharf")
        #expect(loaded.first?.items.first?.name == "Hauslimonade")
    }

    @Test func statusUpdateIsProjectedAndReturned() throws {
        let repo = try EventLogOrderRepository.makeForTesting(base: LocalDemoRepository(), databasePath: try makePath())
        let created = try repo.createOrder(makeOrder())

        let accepted = try repo.updateOrderStatus(orderID: created.id, to: .accepted)
        #expect(accepted?.status == .accepted)
        #expect(try repo.loadOrder(orderID: created.id)?.status == .accepted)
    }

    @Test func updateUnknownOrderReturnsNil() throws {
        let repo = try EventLogOrderRepository.makeForTesting(base: LocalDemoRepository(), databasePath: try makePath())
        #expect(try repo.updateOrderStatus(orderID: "does-not-exist", to: .accepted) == nil)
    }

    @Test func ordersSurviveRepositoryRestart() throws {
        let path = try makePath()

        var repo: EventLogOrderRepository? =
            try EventLogOrderRepository.makeForTesting(base: LocalDemoRepository(), databasePath: path)
        let created = try repo!.createOrder(makeOrder(note: "Merkt sich das?"))
        _ = try repo!.updateOrderStatus(orderID: created.id, to: .accepted)
        repo = nil // release the store; SQLite connection closes on deinit

        let reopened = try EventLogOrderRepository.makeForTesting(base: LocalDemoRepository(), databasePath: path)
        let loaded = try reopened.loadOrders()
        #expect(loaded.count == 1)
        #expect(loaded.first?.id == created.id)
        #expect(loaded.first?.status == .accepted)
        #expect(loaded.first?.customerNote == "Merkt sich das?")
    }

    @Test func clearRemovesVisibleOrders() throws {
        let repo = try EventLogOrderRepository.makeForTesting(base: LocalDemoRepository(), databasePath: try makePath())
        _ = try repo.createOrder(makeOrder())
        _ = try repo.createOrder(makeOrder())
        #expect(try repo.loadOrders().count == 2)

        try repo.clearOrders()
        #expect(try repo.loadOrders().isEmpty)

        let after = try repo.createOrder(makeOrder(note: "nach reset"))
        #expect(try repo.loadOrders().map(\.id) == [after.id])
    }
}
