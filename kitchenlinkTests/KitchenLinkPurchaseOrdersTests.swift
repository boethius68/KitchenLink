import XCTest
@testable import kitchenlink

final class KitchenLinkPurchaseOrdersTests: XCTestCase {

    func testLoadDemoPurchaseOrders() async throws {
        let provider = KitchenLinkPurchaseOrderDemoProvider()
        let orders = try await provider.loadPurchaseOrders()

        XCTAssertEqual(orders.count, 3)

        let sentOrder = try XCTUnwrap(orders.first { $0.orderNumber == "PO-2026-081" })
        XCTAssertEqual(sentOrder.status, .sent)
        XCTAssertEqual(sentOrder.supplierName, "Kochberg Frischegroßhandel")
        XCTAssertEqual(sentOrder.lines.count, 3)
        XCTAssertTrue(sentOrder.status.isActive)
        XCTAssertFalse(sentOrder.status.isTerminal)

        let receivedOrder = try XCTUnwrap(orders.first { $0.orderNumber == "PO-2026-079" })
        XCTAssertEqual(receivedOrder.status, .received)
        XCTAssertNotNil(receivedOrder.receivedAt)
        XCTAssertTrue(receivedOrder.status.isTerminal)
    }

    func testCreatePurchaseOrder() async throws {
        let provider = KitchenLinkPurchaseOrderDemoProvider()
        let lines = [
            KitchenLinkPurchaseOrderLine(
                ingredientID: "ing-1",
                ingredientName: "Kaffee Bohnen",
                quantity: 10,
                unit: "kg",
                pricePerUnitCents: 1500
            )
        ]

        let newOrder = try await provider.createPurchaseOrder(
            supplierID: "sup-kaffee",
            supplierName: "Kaffeerösterei Speicherstadt",
            orderNumber: "PO-9999",
            lines: lines,
            expectedDate: Date(),
            notes: "Dringend"
        )

        XCTAssertEqual(newOrder.orderNumber, "PO-9999")
        XCTAssertEqual(newOrder.status, .draft)
        XCTAssertEqual(newOrder.totalCents, 15000)
        XCTAssertEqual(newOrder.formattedTotal, "150,00 €")

        let allOrders = try await provider.loadPurchaseOrders()
        XCTAssertTrue(allOrders.contains { $0.orderNumber == "PO-9999" })
    }

    func testSendAndReceiveWorkflow() async throws {
        let provider = KitchenLinkPurchaseOrderDemoProvider()
        let orders = try await provider.loadPurchaseOrders()
        let draft = try XCTUnwrap(orders.first { $0.status == .draft })

        // 1. Absenden -> sent
        try await provider.sendPurchaseOrder(orderID: draft.id)
        var currentOrders = try await provider.loadPurchaseOrders()
        var updated = try XCTUnwrap(currentOrders.first { $0.id == draft.id })
        XCTAssertEqual(updated.status, .sent)
        XCTAssertNotNil(updated.sentAt)

        // 2. Wareneingang erfassen -> received
        try await provider.receivePurchaseOrder(orderID: draft.id)
        currentOrders = try await provider.loadPurchaseOrders()
        updated = try XCTUnwrap(currentOrders.first { $0.id == draft.id })
        XCTAssertEqual(updated.status, .received)
        XCTAssertNotNil(updated.receivedAt)
        XCTAssertTrue(updated.status.isTerminal)
    }

    func testLineCalculations() {
        let line = KitchenLinkPurchaseOrderLine(
            ingredientID: "ing-1",
            ingredientName: "Parmesan",
            quantity: 4.5,
            unit: "kg",
            pricePerUnitCents: 2000
        )

        XCTAssertEqual(line.lineTotalCents, 9000)
        XCTAssertEqual(line.formattedQuantity, "4.5 kg")
    }
}
