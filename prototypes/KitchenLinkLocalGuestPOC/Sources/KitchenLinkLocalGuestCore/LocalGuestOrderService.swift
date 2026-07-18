import Foundation
import KitchenLinkEventLog

public final class LocalGuestOrderService: @unchecked Sendable {
    public enum ServiceError: Error, Equatable {
        case invalidRequest(String)
        case idempotencyConflict(existingEventID: String)
        case orderNotFound
        case invalidStatusTransition(from: LocalOperatorOrderStatus, to: LocalOperatorOrderStatus)
        case persistence(String)
    }

    public static let sandboxMenu: [MenuItem] = [
        MenuItem(id: "burger-classic", name: "Classic Burger", description: "Rind, Salat, Tomate, Haussauce", priceMinor: 1290),
        MenuItem(id: "burger-veggie", name: "Veggie Burger", description: "Gemüsepatty, Salat, Tomate, Haussauce", priceMinor: 1190),
        MenuItem(id: "fries", name: "Pommes", description: "Knusprig und leicht gesalzen", priceMinor: 450),
        MenuItem(id: "lemonade", name: "Hauslimonade", description: "Zitrone und Minze", priceMinor: 390)
    ]

    public let venueID: String
    public let venueName: String
    public let menu: [MenuItem]

    private let store: EventStore
    private let deviceID: DeviceID

    public init(
        databasePath: String,
        venueID: String = "venue-local-poc",
        venueName: String = "KitchenLink Testküche",
        deviceID: String = "local-hub-poc",
        menu: [MenuItem] = LocalGuestOrderService.sandboxMenu
    ) throws {
        let connection = try SQLiteConnection(path: databasePath)
        try EventLogSchema.migrate(connection)
        self.store = EventStore(connection: connection)
        self.venueID = venueID
        self.venueName = venueName
        self.deviceID = DeviceID(rawValue: deviceID)
        self.menu = menu
    }

    public func bootstrap() -> BootstrapDocument {
        BootstrapDocument(
            service: "KitchenLink Local Guest Ordering PoC",
            mode: "sandbox-local",
            venueID: venueID,
            venueName: venueName,
            orderEndpoint: "/orders",
            menu: menu
        )
    }

    /// The receipt is constructed only after EventStore.append returns. The
    /// event and cloud outbox row have therefore committed atomically first.
    public func placeOrder(_ request: LocalOrderRequest) throws -> LocalOrderReceipt {
        guard UUID(uuidString: request.orderID) != nil else {
            throw ServiceError.invalidRequest("orderID muss eine UUID sein.")
        }
        guard !request.idempotencyKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              request.idempotencyKey.utf8.count <= 128 else {
            throw ServiceError.invalidRequest("idempotencyKey fehlt oder ist zu lang.")
        }
        guard !request.items.isEmpty, request.items.count <= 30 else {
            throw ServiceError.invalidRequest("Die Bestellung muss 1 bis 30 Positionen enthalten.")
        }

        let byID = Dictionary(uniqueKeysWithValues: menu.map { ($0.id, $0) })
        var quantities: [String: Int] = [:]
        for line in request.items {
            guard byID[line.itemID] != nil else {
                throw ServiceError.invalidRequest("Unbekannter Artikel: \(line.itemID)")
            }
            guard (1...20).contains(line.quantity) else {
                throw ServiceError.invalidRequest("Die Menge muss zwischen 1 und 20 liegen.")
            }
            let combined = (quantities[line.itemID] ?? 0) + line.quantity
            guard combined <= 20 else {
                throw ServiceError.invalidRequest("Maximal 20 Stück pro Artikel sind erlaubt.")
            }
            quantities[line.itemID] = combined
        }

        let acceptedLines = try quantities.keys.sorted().map { itemID -> AcceptedOrderLine in
            guard let item = byID[itemID], let quantity = quantities[itemID] else {
                throw ServiceError.invalidRequest("Artikel konnte nicht aufgelöst werden.")
            }
            return AcceptedOrderLine(
                itemID: item.id,
                name: item.name,
                quantity: quantity,
                unitPriceMinor: item.priceMinor,
                lineTotalMinor: item.priceMinor * quantity
            )
        }
        let total = acceptedLines.reduce(0) { $0 + $1.lineTotalMinor }
        let payload = AcceptedOrderPayload(
            orderID: request.orderID,
            venueID: venueID,
            currency: "EUR",
            totalMinor: total,
            lines: acceptedLines
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let payloadData: Data
        do {
            payloadData = try encoder.encode(payload)
        } catch {
            throw ServiceError.persistence("Bestellpayload konnte nicht serialisiert werden: \(error)")
        }

        let eventVenueID = VenueID(rawValue: venueID)
        let aggregateID = AggregateID(rawValue: request.orderID)
        let fingerprint = Fingerprint.canonical(
            venueID: eventVenueID,
            aggregateType: "order",
            aggregateID: aggregateID,
            eventType: "guest_order_placed",
            payloadVersion: 1,
            payload: payloadData
        )
        let appendRequest = AppendEventRequest(
            eventID: EventID(),
            venueID: eventVenueID,
            aggregateID: aggregateID,
            aggregateType: "order",
            eventType: "guest_order_placed",
            payloadVersion: 1,
            payload: payloadData,
            requestFingerprint: fingerprint,
            idempotencyKey: IdempotencyKey(rawValue: request.idempotencyKey),
            deviceID: deviceID,
            outboxTargets: [.cloud]
        )

        do {
            let result = try store.append(appendRequest, expectedRevision: 0)
            return LocalOrderReceipt(
                status: "accepted",
                orderID: result.event.aggregateID.rawValue,
                eventID: result.event.eventID.rawValue,
                localSequence: result.event.localSeq,
                totalMinor: total,
                currency: "EUR",
                replayed: result.wasReplay,
                persistence: "local-event-log-committed"
            )
        } catch let error as EventStore.AppendError {
            switch error {
            case .idempotencyConflict(_, _, let existingEventID):
                throw ServiceError.idempotencyConflict(existingEventID: existingEventID.rawValue)
            default:
                throw ServiceError.persistence(String(describing: error))
            }
        } catch {
            throw ServiceError.persistence(String(describing: error))
        }
    }

    public func persistedEvents() throws -> [EventRecord] {
        try store.events(forVenue: VenueID(rawValue: venueID))
    }

    public func operatorOrders() throws -> [LocalOperatorOrder] {
        let events = try persistedEvents()
        let grouped = Dictionary(grouping: events, by: { $0.aggregateID.rawValue })
        return try grouped.values.compactMap { aggregateEvents in
            try projectOrder(from: aggregateEvents)
        }
        .sorted { lhs, rhs in
            if lhs.createdAtMs != rhs.createdAtMs { return lhs.createdAtMs < rhs.createdAtMs }
            return lhs.localSequence < rhs.localSequence
        }
    }

    public func updateOperatorOrderStatus(
        orderID: String,
        request: LocalOrderStatusRequest
    ) throws -> LocalOrderStatusReceipt {
        guard UUID(uuidString: orderID) != nil else {
            throw ServiceError.invalidRequest("orderID muss eine UUID sein.")
        }
        guard !request.idempotencyKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              request.idempotencyKey.utf8.count <= 128 else {
            throw ServiceError.invalidRequest("idempotencyKey fehlt oder ist zu lang.")
        }

        let aggregateID = AggregateID(rawValue: orderID)
        let aggregateEvents = try store.events(forAggregate: aggregateID)
        guard let currentOrder = try projectOrder(from: aggregateEvents) else {
            throw ServiceError.orderNotFound
        }

        if let previousEvent = aggregateEvents.first(where: {
            $0.idempotencyKey.rawValue == request.idempotencyKey
        }) {
            guard previousEvent.eventType == "operator_order_status_changed",
                  let previousPayload = try? JSONDecoder().decode(
                    LocalOrderStatusEventPayload.self,
                    from: previousEvent.payload
                  ),
                  previousPayload.targetStatus == request.targetStatus else {
                throw ServiceError.idempotencyConflict(existingEventID: previousEvent.eventID.rawValue)
            }
            return LocalOrderStatusReceipt(
                status: "accepted",
                orderID: orderID,
                orderStatus: request.targetStatus,
                eventID: previousEvent.eventID.rawValue,
                localSequence: previousEvent.localSeq,
                replayed: true,
                persistence: "local-event-log-committed"
            )
        }

        if !currentOrder.status.canTransition(to: request.targetStatus) {
            throw ServiceError.invalidStatusTransition(from: currentOrder.status, to: request.targetStatus)
        }

        let payload = LocalOrderStatusEventPayload(orderID: orderID, targetStatus: request.targetStatus)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let payloadData: Data
        do {
            payloadData = try encoder.encode(payload)
        } catch {
            throw ServiceError.persistence("Statuspayload konnte nicht serialisiert werden: \(error)")
        }

        let eventVenueID = VenueID(rawValue: venueID)
        let fingerprint = Fingerprint.canonical(
            venueID: eventVenueID,
            aggregateType: "order",
            aggregateID: aggregateID,
            eventType: "operator_order_status_changed",
            payloadVersion: 1,
            payload: payloadData
        )
        let appendRequest = AppendEventRequest(
            eventID: EventID(),
            venueID: eventVenueID,
            aggregateID: aggregateID,
            aggregateType: "order",
            eventType: "operator_order_status_changed",
            payloadVersion: 1,
            payload: payloadData,
            requestFingerprint: fingerprint,
            idempotencyKey: IdempotencyKey(rawValue: request.idempotencyKey),
            deviceID: deviceID,
            outboxTargets: [.cloud]
        )

        do {
            let currentRevision = try store.currentRevision(forAggregate: aggregateID)
            let result = try store.append(appendRequest, expectedRevision: currentRevision)
            return LocalOrderStatusReceipt(
                status: "accepted",
                orderID: orderID,
                orderStatus: request.targetStatus,
                eventID: result.event.eventID.rawValue,
                localSequence: result.event.localSeq,
                replayed: result.wasReplay,
                persistence: "local-event-log-committed"
            )
        } catch let error as EventStore.AppendError {
            switch error {
            case .idempotencyConflict(_, _, let existingEventID):
                throw ServiceError.idempotencyConflict(existingEventID: existingEventID.rawValue)
            default:
                throw ServiceError.persistence(String(describing: error))
            }
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.persistence(String(describing: error))
        }
    }

    private func projectOrder(from events: [EventRecord]) throws -> LocalOperatorOrder? {
        let sortedEvents = events.sorted { $0.localSeq < $1.localSeq }
        guard let placed = sortedEvents.first(where: { $0.eventType == "guest_order_placed" }) else {
            return nil
        }

        let decoder = JSONDecoder()
        let payload: AcceptedOrderPayload
        do {
            payload = try decoder.decode(AcceptedOrderPayload.self, from: placed.payload)
        } catch {
            throw ServiceError.persistence("Gespeicherte Bestellung konnte nicht gelesen werden: \(error)")
        }

        var status: LocalOperatorOrderStatus = .preparing
        for event in sortedEvents where event.eventType == "operator_order_status_changed" {
            do {
                status = try decoder.decode(LocalOrderStatusEventPayload.self, from: event.payload).targetStatus
            } catch {
                throw ServiceError.persistence("Gespeicherter Status konnte nicht gelesen werden: \(error)")
            }
        }

        return LocalOperatorOrder(
            id: payload.orderID,
            localSequence: placed.localSeq,
            createdAtMs: placed.occurredAtMs,
            venueID: payload.venueID,
            currency: payload.currency,
            totalMinor: payload.totalMinor,
            lines: payload.lines,
            status: status
        )
    }
}
