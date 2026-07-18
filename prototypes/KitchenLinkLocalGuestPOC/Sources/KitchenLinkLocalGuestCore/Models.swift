import Foundation

public struct MenuItem: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let priceMinor: Int
    public let currency: String

    public init(id: String, name: String, description: String, priceMinor: Int, currency: String = "EUR") {
        self.id = id
        self.name = name
        self.description = description
        self.priceMinor = priceMinor
        self.currency = currency
    }
}

public struct OrderLineRequest: Codable, Equatable, Sendable {
    public let itemID: String
    public let quantity: Int

    public init(itemID: String, quantity: Int) {
        self.itemID = itemID
        self.quantity = quantity
    }
}

public struct LocalOrderRequest: Codable, Equatable, Sendable {
    public let orderID: String
    public let idempotencyKey: String
    public let items: [OrderLineRequest]
    public let clientTotalMinor: Int?

    public init(orderID: String, idempotencyKey: String, items: [OrderLineRequest], clientTotalMinor: Int? = nil) {
        self.orderID = orderID
        self.idempotencyKey = idempotencyKey
        self.items = items
        self.clientTotalMinor = clientTotalMinor
    }
}

public struct AcceptedOrderLine: Codable, Equatable, Sendable {
    public let itemID: String
    public let name: String
    public let quantity: Int
    public let unitPriceMinor: Int
    public let lineTotalMinor: Int
}

public struct AcceptedOrderPayload: Codable, Equatable, Sendable {
    public let orderID: String
    public let venueID: String
    public let currency: String
    public let totalMinor: Int
    public let lines: [AcceptedOrderLine]
}

public struct LocalOrderReceipt: Codable, Equatable, Sendable {
    public let status: String
    public let orderID: String
    public let eventID: String
    public let localSequence: Int64
    public let totalMinor: Int
    public let currency: String
    public let replayed: Bool
    public let persistence: String
}

public struct BootstrapDocument: Codable, Equatable, Sendable {
    public let service: String
    public let mode: String
    public let venueID: String
    public let venueName: String
    public let orderEndpoint: String
    public let menu: [MenuItem]
}

public struct APIErrorDocument: Codable, Equatable, Sendable {
    public let error: String
    public let message: String
}
