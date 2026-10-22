import Foundation

/// KL-PURCHASE-001: Lieferantenbestellungen & automatischer Wareneingang (Blueprint §11 & Meilenstein 4).
///
/// Modelliert den Beschaffungszyklus für Gastronomen:
/// Entwurf -> An Lieferant versendet -> Wareneingang eingebucht / Storniert.

public enum KitchenLinkPurchaseOrderStatus: String, CaseIterable, Identifiable, Sendable {
    case draft = "draft"
    case sent = "sent"
    case received = "received"
    case cancelled = "cancelled"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .draft: return "Entwurf"
        case .sent: return "Versendet"
        case .received: return "Ware erhalten"
        case .cancelled: return "Storniert"
        }
    }

    public var systemIcon: String {
        switch self {
        case .draft: return "doc.text"
        case .sent: return "paperplane.fill"
        case .received: return "checkmark.seal.fill"
        case .cancelled: return "xmark.circle"
        }
    }

    public var isActive: Bool {
        self == .draft || self == .sent
    }

    public var isTerminal: Bool {
        self == .received || self == .cancelled
    }
}

public struct KitchenLinkPurchaseOrderLine: Identifiable, Equatable, Sendable {
    public let id: String
    public var ingredientID: String
    public var ingredientName: String
    public var quantity: Decimal
    public var unit: String
    public var pricePerUnitCents: Int

    public init(
        id: String = UUID().uuidString,
        ingredientID: String,
        ingredientName: String,
        quantity: Decimal,
        unit: String,
        pricePerUnitCents: Int = 0
    ) {
        self.id = id
        self.ingredientID = ingredientID
        self.ingredientName = ingredientName
        self.quantity = quantity
        self.unit = unit
        self.pricePerUnitCents = pricePerUnitCents
    }

    public var lineTotalCents: Int {
        Int((quantity as NSDecimalNumber).doubleValue * Double(pricePerUnitCents))
    }

    public var formattedQuantity: String {
        "\(quantity) \(unit)"
    }
}

public struct KitchenLinkPurchaseOrder: Identifiable, Equatable, Sendable {
    public let id: String
    public var orderNumber: String
    public var supplierID: String
    public var supplierName: String
    public var supplierContact: String?
    public var status: KitchenLinkPurchaseOrderStatus
    public var totalCents: Int
    public var expectedDeliveryDate: Date?
    public var notes: String?
    public var createdAt: Date
    public var sentAt: Date?
    public var receivedAt: Date?
    public var lines: [KitchenLinkPurchaseOrderLine]

    public init(
        id: String = UUID().uuidString,
        orderNumber: String,
        supplierID: String,
        supplierName: String,
        supplierContact: String? = nil,
        status: KitchenLinkPurchaseOrderStatus = .draft,
        totalCents: Int = 0,
        expectedDeliveryDate: Date? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        sentAt: Date? = nil,
        receivedAt: Date? = nil,
        lines: [KitchenLinkPurchaseOrderLine] = []
    ) {
        self.id = id
        self.orderNumber = orderNumber
        self.supplierID = supplierID
        self.supplierName = supplierName
        self.supplierContact = supplierContact
        self.status = status
        self.totalCents = totalCents
        self.expectedDeliveryDate = expectedDeliveryDate
        self.notes = notes
        self.createdAt = createdAt
        self.sentAt = sentAt
        self.receivedAt = receivedAt
        self.lines = lines
    }

    public var formattedTotal: String {
        let euros = Double(totalCents) / 100.0
        return String(format: "%.2f €", locale: Locale(identifier: "de_DE"), euros)
    }

    public var itemsSummary: String {
        if lines.isEmpty { return "Keine Positionen" }
        return lines.map { "\($0.quantity) \($0.unit) \($0.ingredientName)" }.joined(separator: ", ")
    }
}

public protocol KitchenLinkPurchaseOrderProviding: Sendable {
    func loadPurchaseOrders() async throws -> [KitchenLinkPurchaseOrder]
    func createPurchaseOrder(
        supplierID: String,
        supplierName: String,
        orderNumber: String,
        lines: [KitchenLinkPurchaseOrderLine],
        expectedDate: Date?,
        notes: String?
    ) async throws -> KitchenLinkPurchaseOrder
    func sendPurchaseOrder(orderID: String) async throws
    func receivePurchaseOrder(orderID: String) async throws
}

public actor KitchenLinkPurchaseOrderDemoProvider: KitchenLinkPurchaseOrderProviding {
    private var orders: [KitchenLinkPurchaseOrder]

    public init() {
        let now = Date()
        self.orders = [
            KitchenLinkPurchaseOrder(
                orderNumber: "PO-2026-081",
                supplierID: InventorySandboxFixture.supplierKochBerg,
                supplierName: "Kochberg Frischegroßhandel",
                supplierContact: "bestellung@kochberg-frische.de",
                status: .sent,
                totalCents: 18450,
                expectedDeliveryDate: now.addingTimeInterval(24 * 3600),
                notes: "Bitte Anlieferung bis 10:00 Uhr über den Hinterhof.",
                createdAt: now.addingTimeInterval(-18 * 3600),
                sentAt: now.addingTimeInterval(-16 * 3600),
                lines: [
                    KitchenLinkPurchaseOrderLine(
                        ingredientID: InventorySandboxFixture.ingredientFlour,
                        ingredientName: "Mehl Type 00",
                        quantity: 25,
                        unit: "kg",
                        pricePerUnitCents: 120
                    ),
                    KitchenLinkPurchaseOrderLine(
                        ingredientID: InventorySandboxFixture.ingredientMozzarella,
                        ingredientName: "Mozzarella",
                        quantity: 10,
                        unit: "kg",
                        pricePerUnitCents: 850
                    ),
                    KitchenLinkPurchaseOrderLine(
                        ingredientID: InventorySandboxFixture.ingredientTomato,
                        ingredientName: "San-Marzano-Tomaten",
                        quantity: 15,
                        unit: "kg",
                        pricePerUnitCents: 450
                    )
                ]
            ),
            KitchenLinkPurchaseOrder(
                orderNumber: "PO-2026-082",
                supplierID: InventorySandboxFixture.supplierWeinGut,
                supplierName: "Weingut Hölle & Söhne",
                supplierContact: "vertrieb@weingut-hoelle.de",
                status: .draft,
                totalCents: 32000,
                expectedDeliveryDate: now.addingTimeInterval(3 * 24 * 3600),
                notes: "Standard-Monatsorder",
                createdAt: now.addingTimeInterval(-2 * 3600),
                lines: [
                    KitchenLinkPurchaseOrderLine(
                        ingredientID: InventorySandboxFixture.ingredientRedWine,
                        ingredientName: "Rotwein Riserva",
                        quantity: 24,
                        unit: "count",
                        pricePerUnitCents: 950
                    ),
                    KitchenLinkPurchaseOrderLine(
                        ingredientID: InventorySandboxFixture.ingredientWhiteWine,
                        ingredientName: "Grauburgunder Trocken",
                        quantity: 12,
                        unit: "count",
                        pricePerUnitCents: 750
                    )
                ]
            ),
            KitchenLinkPurchaseOrder(
                orderNumber: "PO-2026-079",
                supplierID: InventorySandboxFixture.supplierKochBerg,
                supplierName: "Kochberg Frischegroßhandel",
                supplierContact: "bestellung@kochberg-frische.de",
                status: .received,
                totalCents: 9800,
                createdAt: now.addingTimeInterval(-5 * 24 * 3600),
                sentAt: now.addingTimeInterval(-4 * 24 * 3600),
                receivedAt: now.addingTimeInterval(-2 * 24 * 3600),
                lines: [
                    KitchenLinkPurchaseOrderLine(
                        ingredientID: InventorySandboxFixture.ingredientOliveOil,
                        ingredientName: "Olivenöl Extra Vergine",
                        quantity: 10,
                        unit: "l",
                        pricePerUnitCents: 980
                    )
                ]
            )
        ]
    }

    public func loadPurchaseOrders() async throws -> [KitchenLinkPurchaseOrder] {
        return orders
    }

    public func createPurchaseOrder(
        supplierID: String,
        supplierName: String,
        orderNumber: String,
        lines: [KitchenLinkPurchaseOrderLine],
        expectedDate: Date?,
        notes: String?
    ) async throws -> KitchenLinkPurchaseOrder {
        let total = lines.reduce(0) { $0 + $1.lineTotalCents }
        let newOrder = KitchenLinkPurchaseOrder(
            orderNumber: orderNumber,
            supplierID: supplierID,
            supplierName: supplierName,
            status: .draft,
            totalCents: total,
            expectedDeliveryDate: expectedDate,
            notes: notes,
            createdAt: Date(),
            lines: lines
        )
        orders.insert(newOrder, at: 0)
        return newOrder
    }

    public func sendPurchaseOrder(orderID: String) async throws {
        guard let index = orders.firstIndex(where: { $0.id == orderID }) else {
            throw KitchenLinkPurchaseOrderError.orderNotFound
        }
        orders[index].status = .sent
        orders[index].sentAt = Date()
    }

    public func receivePurchaseOrder(orderID: String) async throws {
        guard let index = orders.firstIndex(where: { $0.id == orderID }) else {
            throw KitchenLinkPurchaseOrderError.orderNotFound
        }
        orders[index].status = .received
        orders[index].receivedAt = Date()
    }
}

public enum KitchenLinkPurchaseOrderError: LocalizedError, Sendable {
    case orderNotFound
    case invalidStatusTransition

    public var errorDescription: String? {
        switch self {
        case .orderNotFound: return "Lieferantenbestellung nicht gefunden."
        case .invalidStatusTransition: return "Ungültiger Statusübergang für die Lieferantenbestellung."
        }
    }
}
