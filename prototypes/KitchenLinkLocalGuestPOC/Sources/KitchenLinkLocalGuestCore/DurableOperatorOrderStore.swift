import Foundation
import KitchenLinkEventLog

/// A single order as projected from the durable event log.
///
/// The order's domain shape is deliberately opaque (`snapshot: Data`) and the
/// status is an opaque `String`. The KitchenLink app owns the meaning of both;
/// keeping them opaque lets this store live in the package without depending on
/// any app-target type.
public struct StoredOperatorOrder: Equatable, Sendable {
    /// Stable order identifier (the aggregate id in the event log).
    public let orderID: String
    /// Storage partition this order belongs to.
    public let venueID: String
    /// Opaque order snapshot exactly as it was placed. The caller owns its shape.
    public let snapshot: Data
    /// Current projected status (opaque to the store).
    public let status: String
    /// The event-log sequence of the placing event (stable creation order).
    public let localSequence: Int64
    /// Domain time the order was placed, in epoch milliseconds.
    public let createdAtMs: Int64

    public init(
        orderID: String,
        venueID: String,
        snapshot: Data,
        status: String,
        localSequence: Int64,
        createdAtMs: Int64
    ) {
        self.orderID = orderID
        self.venueID = venueID
        self.snapshot = snapshot
        self.status = status
        self.localSequence = localSequence
        self.createdAtMs = createdAtMs
    }
}

/// A durable, append-only store for operator-side orders on a single device.
///
/// This is the local-first persistence seam from
/// `docs/architecture/offline/EVENT_LOG_V2.md` §12: every order and every status
/// change is recorded as an authoritative event in the same crash-safe event log
/// (KL-OFFLINE-003) the guest hub already uses, instead of a `UserDefaults` blob.
/// A single device therefore keeps working — and loses nothing — when the cloud
/// is unavailable or the app is killed and relaunched. Each committed order also
/// produces a `cloud` outbox row, so the later cloud reconcile has an exact,
/// idempotent queue to drain.
///
/// The store does not interpret order status semantics; the app validates
/// transitions before calling. Idempotency keys are derived from the order id
/// and target status, so retries of the same logical write deduplicate while the
/// forward-only order lifecycle never collides.
public final class DurableOperatorOrderStore: @unchecked Sendable {
    public enum StoreError: Error, Equatable {
        /// The same order id was placed again with a different snapshot.
        case idempotencyConflict(existingEventID: String)
        /// The storage layer failed.
        case persistence(String)
    }

    // Event + aggregate type names are persisted in the log; keep them stable.
    private static let aggregateTypeOrder = "order"
    private static let aggregateTypeClear = "order_clear"
    private static let eventPlaced = "operator_order_placed"
    private static let eventStatusChanged = "operator_order_status_changed"
    private static let eventCleared = "operator_orders_cleared"
    private static let payloadVersion = 1

    private let store: EventStore
    private let connection: SQLiteConnection
    private let deviceID: DeviceID
    private let clock: Clock

    /// The underlying event store. Exposed so the app target can create
    /// outbox dispatchers for cloud sync without duplicating the connection.
    public var eventStore: EventStore { store }

    /// Opens (creating if needed) the durable order log at `databasePath`.
    public init(databasePath: String, deviceID: String, clock: Clock = SystemClock()) throws {
        let connection = try SQLiteConnection(path: databasePath)
        try EventLogSchema.migrate(connection)
        self.store = EventStore(connection: connection, clock: clock)
        self.connection = connection
        self.deviceID = DeviceID(rawValue: deviceID)
        self.clock = clock
    }

    // MARK: - Writes

    /// Records a placed order. A retry with the same id and snapshot replays the
    /// original event (no duplicate). The same id with a different snapshot is an
    /// idempotency conflict.
    @discardableResult
    public func placeOrder(
        orderID: String,
        venueID: String,
        snapshot: Data,
        initialStatus: String,
        occurredAtMs: Int64? = nil
    ) throws -> StoredOperatorOrder {
        let payload = try encode(PlacedEnvelope(status: initialStatus, snapshot: snapshot), context: "Bestellung")
        let request = makeRequest(
            eventType: Self.eventPlaced,
            aggregateType: Self.aggregateTypeOrder,
            aggregateID: orderID,
            venueID: venueID,
            payload: payload,
            idempotencyKey: "place:\(orderID)",
            occurredAtMs: occurredAtMs
        )
        do {
            let result = try store.append(request, expectedRevision: 0)
            return StoredOperatorOrder(
                orderID: orderID,
                venueID: venueID,
                snapshot: snapshot,
                status: initialStatus,
                localSequence: result.event.localSeq,
                createdAtMs: result.event.occurredAtMs
            )
        } catch let error as EventStore.AppendError {
            throw mapAppendError(error)
        } catch {
            throw StoreError.persistence(String(describing: error))
        }
    }

    /// Records a status change. Returns `nil` if no order with `orderID` exists.
    /// A retry of the same transition replays the original event.
    @discardableResult
    public func updateStatus(
        orderID: String,
        venueID: String,
        to status: String,
        occurredAtMs: Int64? = nil
    ) throws -> StoredOperatorOrder? {
        let aggregateID = AggregateID(rawValue: orderID)
        let aggregateEvents: [EventRecord]
        do {
            aggregateEvents = try store.events(forAggregate: aggregateID)
        } catch {
            throw StoreError.persistence(String(describing: error))
        }
        guard aggregateEvents.contains(where: { $0.eventType == Self.eventPlaced }) else {
            return nil
        }

        let payload = try encode(StatusEnvelope(status: status), context: "Status")
        let request = makeRequest(
            eventType: Self.eventStatusChanged,
            aggregateType: Self.aggregateTypeOrder,
            aggregateID: orderID,
            venueID: venueID,
            payload: payload,
            idempotencyKey: "status:\(orderID):\(status)",
            occurredAtMs: occurredAtMs
        )
        do {
            let currentRevision = try store.currentRevision(forAggregate: aggregateID)
            _ = try store.append(request, expectedRevision: currentRevision)
            return try order(orderID: orderID, venueID: venueID)
        } catch let error as EventStore.AppendError {
            throw mapAppendError(error)
        } catch let error as StoreError {
            throw error
        } catch {
            throw StoreError.persistence(String(describing: error))
        }
    }

    /// Hides all orders placed up to now for `venueID` by recording a clear
    /// marker. The events themselves remain in the append-only log; only the
    /// projection stops returning them. Mirrors `LocalDemoRepository.clearOrders`.
    public func clear(venueID: String, occurredAtMs: Int64? = nil) throws {
        let markerID = "clear:\(UUID().uuidString.lowercased())"
        let payload = try encode(
            ClearEnvelope(clearedAtMs: occurredAtMs ?? clock.nowMs()),
            context: "Zurücksetzen"
        )
        let request = makeRequest(
            eventType: Self.eventCleared,
            aggregateType: Self.aggregateTypeClear,
            aggregateID: markerID,
            venueID: venueID,
            payload: payload,
            idempotencyKey: markerID,
            occurredAtMs: occurredAtMs
        )
        do {
            _ = try store.append(request, expectedRevision: 0)
        } catch {
            throw StoreError.persistence(String(describing: error))
        }
    }

    // MARK: - Reads

    /// All currently visible orders for `venueID`, oldest first. Orders placed at
    /// or before the latest clear marker are omitted.
    public func orders(venueID: String) throws -> [StoredOperatorOrder] {
        let events: [EventRecord]
        do {
            events = try store.events(forVenue: VenueID(rawValue: venueID))
        } catch {
            throw StoreError.persistence(String(describing: error))
        }

        let clearCutoff = events
            .filter { $0.eventType == Self.eventCleared }
            .map(\.localSeq)
            .max() ?? 0

        let grouped = Dictionary(
            grouping: events.filter { $0.aggregateType == Self.aggregateTypeOrder },
            by: { $0.aggregateID.rawValue }
        )

        var projected: [StoredOperatorOrder] = []
        for (orderID, aggregateEvents) in grouped {
            guard let order = try project(orderID: orderID, venueID: venueID, events: aggregateEvents),
                  order.localSequence > clearCutoff else {
                continue
            }
            projected.append(order)
        }

        return projected.sorted { lhs, rhs in
            if lhs.createdAtMs != rhs.createdAtMs { return lhs.createdAtMs < rhs.createdAtMs }
            return lhs.localSequence < rhs.localSequence
        }
    }

    public func order(orderID: String, venueID: String) throws -> StoredOperatorOrder? {
        let events: [EventRecord]
        do {
            events = try store.events(forAggregate: AggregateID(rawValue: orderID))
        } catch {
            throw StoreError.persistence(String(describing: error))
        }
        return try project(orderID: orderID, venueID: venueID, events: events)
    }

    // MARK: - Projection

    private func project(
        orderID: String,
        venueID: String,
        events: [EventRecord]
    ) throws -> StoredOperatorOrder? {
        let sorted = events.sorted { $0.localSeq < $1.localSeq }
        guard let placed = sorted.first(where: { $0.eventType == Self.eventPlaced }) else {
            return nil
        }

        let placedEnvelope: PlacedEnvelope
        do {
            placedEnvelope = try JSONDecoder().decode(PlacedEnvelope.self, from: placed.payload)
        } catch {
            throw StoreError.persistence("Bestellung konnte nicht gelesen werden: \(error)")
        }

        var status = placedEnvelope.status
        for event in sorted where event.eventType == Self.eventStatusChanged {
            do {
                status = try JSONDecoder().decode(StatusEnvelope.self, from: event.payload).status
            } catch {
                throw StoreError.persistence("Status konnte nicht gelesen werden: \(error)")
            }
        }

        return StoredOperatorOrder(
            orderID: orderID,
            venueID: venueID,
            snapshot: placedEnvelope.snapshot,
            status: status,
            localSequence: placed.localSeq,
            createdAtMs: placed.occurredAtMs
        )
    }

    // MARK: - Helpers

    private func makeRequest(
        eventType: String,
        aggregateType: String,
        aggregateID: String,
        venueID: String,
        payload: Data,
        idempotencyKey: String,
        occurredAtMs: Int64?
    ) -> AppendEventRequest {
        let venue = VenueID(rawValue: venueID)
        let aggregate = AggregateID(rawValue: aggregateID)
        let fingerprint = Fingerprint.canonical(
            venueID: venue,
            aggregateType: aggregateType,
            aggregateID: aggregate,
            eventType: eventType,
            payloadVersion: Self.payloadVersion,
            payload: payload
        )
        return AppendEventRequest(
            eventID: EventID(),
            venueID: venue,
            aggregateID: aggregate,
            aggregateType: aggregateType,
            eventType: eventType,
            payloadVersion: Self.payloadVersion,
            payload: payload,
            requestFingerprint: fingerprint,
            idempotencyKey: IdempotencyKey(rawValue: idempotencyKey),
            deviceID: deviceID,
            occurredAtMs: occurredAtMs,
            outboxTargets: [.cloud]
        )
    }

    private func encode<T: Encodable>(_ value: T, context: String) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        do {
            return try encoder.encode(value)
        } catch {
            throw StoreError.persistence("\(context) konnte nicht serialisiert werden: \(error)")
        }
    }

    private func mapAppendError(_ error: EventStore.AppendError) -> StoreError {
        switch error {
        case .idempotencyConflict(_, _, let existingEventID):
            return .idempotencyConflict(existingEventID: existingEventID.rawValue)
        case .optimisticConcurrencyConflict, .duplicateEventID:
            return .persistence(String(describing: error))
        case .storage(let message):
            return .persistence(message)
        }
    }
}

private struct PlacedEnvelope: Codable {
    let status: String
    let snapshot: Data
}

private struct StatusEnvelope: Codable {
    let status: String
}

private struct ClearEnvelope: Codable {
    let clearedAtMs: Int64
}
