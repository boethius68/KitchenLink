import Foundation
import KitchenLinkEventLog
import KitchenLinkLocalGuestCore

/// A `KitchenLinkRepository` that keeps orders in the durable, append-only event
/// log (KL-OFFLINE-003) instead of `UserDefaults`, so a single device stays
/// local-first: orders and status changes survive an app kill, a crash or a
/// cloud outage, and nothing is silently lost. Every committed order also queues
/// a `cloud` outbox row for the later reconcile.
///
/// Venue, menu and QR data continue to be served by an embedded
/// `LocalDemoRepository`. This seam replaces only the order persistence, in line
/// with `docs/architecture/offline/EVENT_LOG_V2.md` §12 and Blueprint §18.1
/// ("alter Code wird erst entfernt, wenn ein getesteter Ersatz existiert"): the
/// demo repository stays fully intact and continues to back every demo/test path.
final class EventLogOrderRepository: KitchenLinkRepository {
    /// All locally stored orders live in one device-scoped partition. Each
    /// order's own venue id is preserved inside the snapshot for display.
    static let localVenuePartition = "kitchenlink-local-orders"

    private let base: LocalDemoRepository
    private let store: DurableOperatorOrderStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(base: LocalDemoRepository, store: DurableOperatorOrderStore) {
        self.base = base
        self.store = store
    }

    // MARK: - Venue / menu / QR (delegated to the demo repository)

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

    // MARK: - Orders (durable event log)

    func loadOrders() throws -> [LiveOrderMessage] {
        try store.orders(venueID: Self.localVenuePartition)
            .compactMap(decodeOrder)
            .sorted { $0.createdAt > $1.createdAt }
    }

    func loadOrder(orderID: String) throws -> LiveOrderMessage? {
        guard let stored = try store.order(orderID: orderID, venueID: Self.localVenuePartition) else {
            return nil
        }
        return decodeOrder(stored)
    }

    func createOrder(_ order: LiveOrderMessage) throws -> LiveOrderMessage {
        let orderID = order.id.isEmpty ? UUID().uuidString.lowercased() : order.id
        let placed = order.with(id: orderID, status: .pending)
        let snapshot = try encoder.encode(placed)
        _ = try store.placeOrder(
            orderID: orderID,
            venueID: Self.localVenuePartition,
            snapshot: snapshot,
            initialStatus: OrderLifecycleStatus.pending.rawValue
        )
        return placed
    }

    func updateOrderStatus(orderID: String, to status: OrderLifecycleStatus) throws -> LiveOrderMessage? {
        guard let stored = try store.updateStatus(
            orderID: orderID,
            venueID: Self.localVenuePartition,
            to: status.rawValue
        ) else {
            return nil
        }
        return decodeOrder(stored)
    }

    func clearOrders() throws {
        try store.clear(venueID: Self.localVenuePartition)
    }

    // MARK: - Cloud Outbox Sync

    /// Drains pending cloud outbox entries. Returns the number of events
    /// acknowledged in this tick. An explicit `cloudTransport` can be injected
    /// for testing; defaults to the real Supabase transport.
    func drainCloudOutbox(
        config: KitchenLinkCloudConfig,
        session: KitchenLinkCloudSession,
        cloudTransport: (any KitchenLinkCloudTransport)? = nil
    ) async throws -> Int {
        let eventStore = store.eventStore
        let outbox = Outbox(connection: eventStore.connection, store: eventStore, clock: SystemClock())
        let transport = CloudOutboxTransport(config: config, session: session,
                                             cloudTransport: cloudTransport ?? URLSessionKitchenLinkCloudTransport())
        let dispatcher = OutboxDispatcher(outbox: outbox, transport: transport, target: OutboxTarget(rawValue: "cloud"))
        let result = try await dispatcher.tick(limit: 10)
        return result.acknowledged
    }

    // MARK: - Mapping

    private func decodeOrder(_ stored: StoredOperatorOrder) -> LiveOrderMessage? {
        guard let order = try? decoder.decode(LiveOrderMessage.self, from: stored.snapshot) else {
            return nil
        }
        let status = OrderLifecycleStatus(rawValue: stored.status) ?? order.status
        return order.with(id: order.id, status: status)
    }
}

extension EventLogOrderRepository {
    /// Builds the production repository, storing orders in the app's Application
    /// Support directory. Falls back to a pure `LocalDemoRepository` if the
    /// durable store cannot be opened, so ordering never hard-fails on a storage
    /// problem.
    static func makeDefault(base: LocalDemoRepository = LocalDemoRepository()) -> any KitchenLinkRepository {
        do {
            let fileManager = FileManager.default
            let directory = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("KitchenLinkOrders", isDirectory: true)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

            let store = try DurableOperatorOrderStore(
                databasePath: directory.appendingPathComponent("orders.sqlite").path,
                deviceID: KitchenLinkVenueHubIdentity.deviceID()
            )
            return EventLogOrderRepository(base: base, store: store)
        } catch {
            return base
        }
    }
}

#if DEBUG
extension EventLogOrderRepository {
    /// Test seam: builds a repository whose durable order log lives at
    /// `databasePath`, so tests can exercise persistence without touching the
    /// app's Application Support directory. Kept in the app target so tests need
    /// only `@testable import kitchenlink` (no direct package dependency).
    static func makeForTesting(
        base: LocalDemoRepository,
        databasePath: String,
        deviceID: String = "test-device"
    ) throws -> EventLogOrderRepository {
        let store = try DurableOperatorOrderStore(databasePath: databasePath, deviceID: deviceID)
        return EventLogOrderRepository(base: base, store: store)
    }
}
/// `OutboxTransport` that forwards local outbox events to Supabase RPCs via
/// the shared `URLSessionKitchenLinkCloudTransport`.
final class CloudOutboxTransport: OutboxTransport {
    private let config: KitchenLinkCloudConfig
    private let session: KitchenLinkCloudSession
    private let cloud: any KitchenLinkCloudTransport

    init(config: KitchenLinkCloudConfig, session: KitchenLinkCloudSession,
         cloudTransport: any KitchenLinkCloudTransport = URLSessionKitchenLinkCloudTransport()) {
        self.config = config
        self.session = session
        self.cloud = cloudTransport
    }

    func deliver(_ claim: Outbox.Claim) async throws -> TransportResult {
        switch claim.event.eventType {
        case "operator_order_placed":
            return try await deliverPlaced(claim)
        default:
            return .failed(reason: "unknown event type: \(claim.event.eventType)")
        }
    }

    private struct PlacedEnvelope: Decodable {
        let status: String
        /// Nested snapshot of the full `LiveOrderMessage` as encoded JSON.
        let snapshot: Data
    }

    private func deliverPlaced(_ claim: Outbox.Claim) async throws -> TransportResult {
        let decoder = JSONDecoder()
        guard let envelope = try? decoder.decode(PlacedEnvelope.self, from: claim.event.payload),
              let order = try? decoder.decode(LiveOrderMessage.self, from: envelope.snapshot) else {
            return .failed(reason: "malformed placed-event payload")
        }

        let encoder = JSONEncoder()
        let itemsData: Data
        if let encoded = try? encoder.encode(order.items) {
            itemsData = encoded
        } else {
            return .failed(reason: "could not encode order items")
        }

        do {
            let ok = try await cloud.createOrder(
                config: config,
                session: session,
                venueSlug: OrderTargetURLExtraction.venueSlug ?? "unknown",
                id: order.id,
                createdAt: order.createdAt,
                sourceDevice: "ios-waiter",
                totalCents: order.totalCents,
                serviceMode: order.serviceMode?.rawValue ?? "dine_in",
                customerNote: order.customerNote,
                itemsJSON: itemsData,
                // KL-TABLE-002: der Tisch reist mit der lokal festgeschriebenen
                // Bestellung in die Cloud und öffnet dort die Tisch-Session.
                tableID: order.tableID
            )
            return ok ? .acknowledged(remoteToken: order.id) : .failed(reason: "RPC returned false")
        } catch {
            return .failed(reason: "\(error)")
        }
    }
}

/// Extracts the venue slug from the first loaded venue partition id.
/// The `EventLogOrderRepository` stores all orders under
/// `localVenuePartition` which is NOT the actual venue slug. For now we fall
/// back to the sandbox default.
private enum OrderTargetURLExtraction {
    static var venueSlug: String? {
        KitchenLinkCloudConfig.sandboxDefault.venueSlug
    }
}

#endif
