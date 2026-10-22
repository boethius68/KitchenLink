import Foundation

/// KL-DELIVERY-001: Eigener Lieferbetrieb, Fahrerzuweisung & Tourenstatus (Blueprint §12 & Meilenstein 3).
///
/// Unterstützt den Lieferbetrieb für Betreiber und Fahrer:
/// Statusübergänge (Bereit -> Fahrer zugewiesen -> Unterwegs -> Zugestellt / Fehlgeschlagen),
/// Adressvalidierung, Apple Maps Navigation, Bar- und Online-Zahlung sowie Fahrer-Touren.

public enum KitchenLinkDeliveryStatus: String, CaseIterable, Identifiable, Sendable {
    case pending = "pending"
    case assigned = "assigned"
    case outForDelivery = "out_for_delivery"
    case delivered = "delivered"
    case failed = "failed"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .pending: return "Bereit in Küche"
        case .assigned: return "Fahrer zugewiesen"
        case .outForDelivery: return "Unterwegs"
        case .delivered: return "Zugestellt"
        case .failed: return "Fehlgeschlagen"
        }
    }

    public var systemIcon: String {
        switch self {
        case .pending: return "bag"
        case .assigned: return "person.badge.shield.checkmark"
        case .outForDelivery: return "bicycle"
        case .delivered: return "checkmark.seal.fill"
        case .failed: return "exclamationmark.triangle"
        }
    }

    public var isActive: Bool {
        self == .pending || self == .assigned || self == .outForDelivery
    }

    public var isTerminal: Bool {
        self == .delivered || self == .failed
    }
}

public enum KitchenLinkDeliveryPaymentMethod: String, CaseIterable, Identifiable, Sendable {
    case online = "online"
    case cashOnDelivery = "cash_on_delivery"
    case cardOnDelivery = "card_on_delivery"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .online: return "Online bezahlt"
        case .cashOnDelivery: return "Bar bei Lieferung"
        case .cardOnDelivery: return "Karte bei Lieferung"
        }
    }

    public var isCollectOnDelivery: Bool {
        self == .cashOnDelivery || self == .cardOnDelivery
    }
}

public struct KitchenLinkDeliveryAddress: Equatable, Sendable {
    public var street: String
    public var houseNumber: String
    public var postalCode: String
    public var city: String
    public var floorOrNote: String?

    public init(
        street: String,
        houseNumber: String,
        postalCode: String,
        city: String,
        floorOrNote: String? = nil
    ) {
        self.street = street.trimmingCharacters(in: .whitespacesAndNewlines)
        self.houseNumber = houseNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        self.postalCode = postalCode.trimmingCharacters(in: .whitespacesAndNewlines)
        self.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
        self.floorOrNote = floorOrNote?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var singleLine: String {
        "\(street) \(houseNumber), \(postalCode) \(city)"
    }

    public var appleMapsURL: URL? {
        let query = "\(street) \(houseNumber), \(postalCode) \(city)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "https://maps.apple.com/?daddr=\(encoded)&dirflg=d")
    }
}

public struct KitchenLinkDeliveryDriver: Identifiable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var phone: String?
    public var activeDeliveriesCount: Int

    public init(
        id: String = UUID().uuidString,
        name: String,
        phone: String? = nil,
        activeDeliveriesCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.phone = phone
        self.activeDeliveriesCount = activeDeliveriesCount
    }
}

public struct KitchenLinkDeliveryOrder: Identifiable, Equatable, Sendable {
    public let id: String
    public var orderNumber: String
    public var recipientName: String
    public var phone: String?
    public var address: KitchenLinkDeliveryAddress
    public var itemsSummary: String
    public var itemCount: Int
    public var totalCents: Int
    public var deliveryFeeCents: Int
    public var status: KitchenLinkDeliveryStatus
    public var paymentMethod: KitchenLinkDeliveryPaymentMethod
    public var driverID: String?
    public var driverName: String?
    public var customerNote: String?
    public var createdAt: Date
    public var assignedAt: Date?
    public var dispatchedAt: Date?
    public var deliveredAt: Date?
    public var failureReason: String?

    public init(
        id: String = UUID().uuidString,
        orderNumber: String,
        recipientName: String,
        phone: String? = nil,
        address: KitchenLinkDeliveryAddress,
        itemsSummary: String,
        itemCount: Int = 1,
        totalCents: Int,
        deliveryFeeCents: Int = 250,
        status: KitchenLinkDeliveryStatus = .pending,
        paymentMethod: KitchenLinkDeliveryPaymentMethod = .online,
        driverID: String? = nil,
        driverName: String? = nil,
        customerNote: String? = nil,
        createdAt: Date = Date(),
        assignedAt: Date? = nil,
        dispatchedAt: Date? = nil,
        deliveredAt: Date? = nil,
        failureReason: String? = nil
    ) {
        self.id = id
        self.orderNumber = orderNumber
        self.recipientName = recipientName
        self.phone = phone
        self.address = address
        self.itemsSummary = itemsSummary
        self.itemCount = itemCount
        self.totalCents = totalCents
        self.deliveryFeeCents = deliveryFeeCents
        self.status = status
        self.paymentMethod = paymentMethod
        self.driverID = driverID
        self.driverName = driverName
        self.customerNote = customerNote
        self.createdAt = createdAt
        self.assignedAt = assignedAt
        self.dispatchedAt = dispatchedAt
        self.deliveredAt = deliveredAt
        self.failureReason = failureReason
    }

    public var formattedTotal: String {
        let euros = Double(totalCents) / 100.0
        return String(format: "%.2f €", locale: Locale(identifier: "de_DE"), euros)
    }

    public var transitDurationMinutes: Int? {
        guard let dispatched = dispatchedAt else { return nil }
        let end = deliveredAt ?? Date()
        return max(1, Int(end.timeIntervalSince(dispatched) / 60.0))
    }
}

public struct KitchenLinkDeliveryArea: Identifiable, Equatable, Sendable {
    public let id: String
    public var postalCode: String
    public var city: String
    public var minOrderCents: Int
    public var deliveryFeeCents: Int
    public var isActive: Bool

    public init(
        id: String = UUID().uuidString,
        postalCode: String,
        city: String,
        minOrderCents: Int = 1500,
        deliveryFeeCents: Int = 250,
        isActive: Bool = true
    ) {
        self.id = id
        self.postalCode = postalCode
        self.city = city
        self.minOrderCents = minOrderCents
        self.deliveryFeeCents = deliveryFeeCents
        self.isActive = isActive
    }

    public var formattedMinOrder: String {
        let euros = Double(minOrderCents) / 100.0
        return String(format: "%.2f €", locale: Locale(identifier: "de_DE"), euros)
    }

    public var formattedFee: String {
        let euros = Double(deliveryFeeCents) / 100.0
        return String(format: "%.2f €", locale: Locale(identifier: "de_DE"), euros)
    }
}

public protocol KitchenLinkDeliveryProviding: Sendable {
    func loadDeliveries() async throws -> [KitchenLinkDeliveryOrder]
    func loadAvailableDrivers() async throws -> [KitchenLinkDeliveryDriver]
    func assignDriver(orderID: String, driverID: String, driverName: String) async throws
    func updateStatus(orderID: String, status: KitchenLinkDeliveryStatus, failureReason: String?) async throws
    func loadDeliveryAreas() async throws -> [KitchenLinkDeliveryArea]
}

/// Demo Actor Provider für Tests und die Betreiber-Sandbox.
public actor KitchenLinkDeliveryDemoProvider: KitchenLinkDeliveryProviding {
    private var orders: [KitchenLinkDeliveryOrder]
    private var drivers: [KitchenLinkDeliveryDriver]
    private var areas: [KitchenLinkDeliveryArea]

    public init() {
        let now = Date()
        self.drivers = [
            KitchenLinkDeliveryDriver(name: "Leon Schmidt", phone: "0171 2345678", activeDeliveriesCount: 1),
            KitchenLinkDeliveryDriver(name: "Samira Khan", phone: "0172 9876543", activeDeliveriesCount: 1),
            KitchenLinkDeliveryDriver(name: "Moritz Bauer", phone: "0173 5551234", activeDeliveriesCount: 0)
        ]

        self.areas = [
            KitchenLinkDeliveryArea(postalCode: "10115", city: "Berlin Mitte", minOrderCents: 1500, deliveryFeeCents: 200),
            KitchenLinkDeliveryArea(postalCode: "10117", city: "Berlin Mitte", minOrderCents: 1500, deliveryFeeCents: 200),
            KitchenLinkDeliveryArea(postalCode: "10119", city: "Berlin Prenzlauer Berg", minOrderCents: 2000, deliveryFeeCents: 250),
            KitchenLinkDeliveryArea(postalCode: "10405", city: "Berlin Prenzlauer Berg", minOrderCents: 2500, deliveryFeeCents: 350)
        ]

        self.orders = [
            KitchenLinkDeliveryOrder(
                orderNumber: "L-101",
                recipientName: "Clara Schumann",
                phone: "0170 1122334",
                address: KitchenLinkDeliveryAddress(
                    street: "Torstraße",
                    houseNumber: "140",
                    postalCode: "10119",
                    city: "Berlin",
                    floorOrNote: "3. OG links, Klingel 'Schumann'"
                ),
                itemsSummary: "2x Kürbissuppe, 1x Rindergulasch, 1x Hauslimonade",
                itemCount: 4,
                totalCents: 3850,
                deliveryFeeCents: 250,
                status: .outForDelivery,
                paymentMethod: .online,
                driverID: drivers[0].id,
                driverName: drivers[0].name,
                customerNote: "Bitte nicht klingeln, Baby schläft - kurz anrufen.",
                createdAt: now.addingTimeInterval(-25 * 60),
                assignedAt: now.addingTimeInterval(-18 * 60),
                dispatchedAt: now.addingTimeInterval(-10 * 60)
            ),
            KitchenLinkDeliveryOrder(
                orderNumber: "L-102",
                recipientName: "Dr. Jan Weber",
                phone: "0175 4433221",
                address: KitchenLinkDeliveryAddress(
                    street: "Linienstraße",
                    houseNumber: "88",
                    postalCode: "10115",
                    city: "Berlin",
                    floorOrNote: "Praxis im EG"
                ),
                itemsSummary: "1x Wiener Schnitzel, 1x Großer Salat",
                itemCount: 2,
                totalCents: 2650,
                deliveryFeeCents: 200,
                status: .assigned,
                paymentMethod: .cashOnDelivery,
                driverID: drivers[1].id,
                driverName: drivers[1].name,
                customerNote: "Rechnung mit Firmenname bitte beilegen.",
                createdAt: now.addingTimeInterval(-12 * 60),
                assignedAt: now.addingTimeInterval(-2 * 60)
            ),
            KitchenLinkDeliveryOrder(
                orderNumber: "L-103",
                recipientName: "Elena Varga",
                phone: "0160 8877665",
                address: KitchenLinkDeliveryAddress(
                    street: "Kastanienallee",
                    houseNumber: "23",
                    postalCode: "10405",
                    city: "Berlin",
                    floorOrNote: "Hinterhaus 2. Stock"
                ),
                itemsSummary: "1x Tagliatelle Tartufo, 1x Tiramisù, 1x San Pellegrino",
                itemCount: 3,
                totalCents: 2900,
                deliveryFeeCents: 350,
                status: .pending,
                paymentMethod: .online,
                createdAt: now.addingTimeInterval(-5 * 60)
            ),
            KitchenLinkDeliveryOrder(
                orderNumber: "L-100",
                recipientName: "Maximilian Koch",
                phone: "0151 9988776",
                address: KitchenLinkDeliveryAddress(
                    street: "Friedrichstraße",
                    houseNumber: "102",
                    postalCode: "10117",
                    city: "Berlin"
                ),
                itemsSummary: "2x Cheeseburger Classic, 2x Pommes Frites",
                itemCount: 4,
                totalCents: 3200,
                deliveryFeeCents: 200,
                status: .delivered,
                paymentMethod: .online,
                driverID: drivers[0].id,
                driverName: drivers[0].name,
                createdAt: now.addingTimeInterval(-65 * 60),
                assignedAt: now.addingTimeInterval(-50 * 60),
                dispatchedAt: now.addingTimeInterval(-40 * 60),
                deliveredAt: now.addingTimeInterval(-15 * 60)
            )
        ]
    }

    public func loadDeliveries() async throws -> [KitchenLinkDeliveryOrder] {
        return orders
    }

    public func loadAvailableDrivers() async throws -> [KitchenLinkDeliveryDriver] {
        return drivers
    }

    public func assignDriver(orderID: String, driverID: String, driverName: String) async throws {
        guard let index = orders.firstIndex(where: { $0.id == orderID }) else {
            throw KitchenLinkDeliveryError.orderNotFound
        }
        orders[index].driverID = driverID
        orders[index].driverName = driverName
        orders[index].status = .assigned
        orders[index].assignedAt = Date()
    }

    public func updateStatus(orderID: String, status: KitchenLinkDeliveryStatus, failureReason: String?) async throws {
        guard let index = orders.firstIndex(where: { $0.id == orderID }) else {
            throw KitchenLinkDeliveryError.orderNotFound
        }
        let now = Date()
        orders[index].status = status
        switch status {
        case .outForDelivery:
            if orders[index].dispatchedAt == nil {
                orders[index].dispatchedAt = now
            }
        case .delivered:
            orders[index].deliveredAt = now
        case .failed:
            orders[index].failureReason = failureReason ?? "Zustellung nicht möglich"
        default:
            break
        }
    }

    public func loadDeliveryAreas() async throws -> [KitchenLinkDeliveryArea] {
        return areas
    }
}

public enum KitchenLinkDeliveryError: LocalizedError, Sendable {
    case orderNotFound
    case driverNotFound
    case invalidStatusTransition

    public var errorDescription: String? {
        switch self {
        case .orderNotFound: return "Lieferbestellung nicht gefunden."
        case .driverNotFound: return "Fahrer nicht gefunden."
        case .invalidStatusTransition: return "Ungültiger Lieferstatus-Übergang."
        }
    }
}
