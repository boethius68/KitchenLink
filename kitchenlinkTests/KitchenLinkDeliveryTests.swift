import XCTest
@testable import kitchenlink

final class KitchenLinkDeliveryTests: XCTestCase {

    func testLoadDeliveriesAndDrivers() async throws {
        let provider = KitchenLinkDeliveryDemoProvider()
        let orders = try await provider.loadDeliveries()
        let drivers = try await provider.loadAvailableDrivers()
        let areas = try await provider.loadDeliveryAreas()

        XCTAssertEqual(orders.count, 4)
        XCTAssertEqual(drivers.count, 3)
        XCTAssertEqual(areas.count, 4)

        // L-101 ist unterwegs
        let order101 = try XCTUnwrap(orders.first { $0.orderNumber == "L-101" })
        XCTAssertEqual(order101.status, .outForDelivery)
        XCTAssertEqual(order101.driverName, "Leon Schmidt")
        XCTAssertTrue(order101.status.isActive)
        XCTAssertFalse(order101.status.isTerminal)

        // L-103 ist bereit in der Küche
        let order103 = try XCTUnwrap(orders.first { $0.orderNumber == "L-103" })
        XCTAssertEqual(order103.status, .pending)
        XCTAssertNil(order103.driverID)
    }

    func testAssignDriver() async throws {
        let provider = KitchenLinkDeliveryDemoProvider()
        let orders = try await provider.loadDeliveries()
        let pendingOrder = try XCTUnwrap(orders.first { $0.orderNumber == "L-103" })

        try await provider.assignDriver(
            orderID: pendingOrder.id,
            driverID: "driver-samira",
            driverName: "Samira Khan"
        )

        let updatedOrders = try await provider.loadDeliveries()
        let updatedOrder = try XCTUnwrap(updatedOrders.first { $0.id == pendingOrder.id })

        XCTAssertEqual(updatedOrder.status, .assigned)
        XCTAssertEqual(updatedOrder.driverID, "driver-samira")
        XCTAssertEqual(updatedOrder.driverName, "Samira Khan")
        XCTAssertNotNil(updatedOrder.assignedAt)
    }

    func testStatusTransitions() async throws {
        let provider = KitchenLinkDeliveryDemoProvider()
        let orders = try await provider.loadDeliveries()
        let assignedOrder = try XCTUnwrap(orders.first { $0.orderNumber == "L-102" })

        // 1. Tour starten -> outForDelivery
        try await provider.updateStatus(orderID: assignedOrder.id, status: .outForDelivery, failureReason: nil)
        var allDeliveries = try await provider.loadDeliveries()
        var current = try XCTUnwrap(allDeliveries.first { $0.id == assignedOrder.id })
        XCTAssertEqual(current.status, .outForDelivery)
        XCTAssertNotNil(current.dispatchedAt)

        // 2. Zugestellt -> delivered
        try await provider.updateStatus(orderID: assignedOrder.id, status: .delivered, failureReason: nil)
        allDeliveries = try await provider.loadDeliveries()
        current = try XCTUnwrap(allDeliveries.first { $0.id == assignedOrder.id })
        XCTAssertEqual(current.status, .delivered)
        XCTAssertNotNil(current.deliveredAt)
        XCTAssertTrue(current.status.isTerminal)
    }

    func testFailureHandling() async throws {
        let provider = KitchenLinkDeliveryDemoProvider()
        let orders = try await provider.loadDeliveries()
        let order = try XCTUnwrap(orders.first { $0.orderNumber == "L-101" })

        try await provider.updateStatus(
            orderID: order.id,
            status: .failed,
            failureReason: "Kunde nicht angetroffen: Klingel defekt"
        )

        let updatedOrders = try await provider.loadDeliveries()
        let updated = try XCTUnwrap(updatedOrders.first { $0.id == order.id })
        XCTAssertEqual(updated.status, .failed)
        XCTAssertEqual(updated.failureReason, "Kunde nicht angetroffen: Klingel defekt")
        XCTAssertTrue(updated.status.isTerminal)
    }

    func testAddressSingleLineAndMapsURL() {
        let address = KitchenLinkDeliveryAddress(
            street: "Friedrichstraße",
            houseNumber: "102",
            postalCode: "10117",
            city: "Berlin",
            floorOrNote: "EG"
        )

        XCTAssertEqual(address.singleLine, "Friedrichstraße 102, 10117 Berlin")

        let mapsURL = address.appleMapsURL
        XCTAssertNotNil(mapsURL)
        XCTAssertTrue(mapsURL?.absoluteString.contains("https://maps.apple.com/?daddr=") ?? false)
        XCTAssertTrue(mapsURL?.absoluteString.contains("Friedrichstra") ?? false)
    }

    func testPaymentMethodAndFormatting() {
        let order = KitchenLinkDeliveryOrder(
            orderNumber: "L-200",
            recipientName: "Test",
            address: KitchenLinkDeliveryAddress(street: "Test", houseNumber: "1", postalCode: "10115", city: "Berlin"),
            itemsSummary: "Pizza",
            totalCents: 2450,
            status: .pending,
            paymentMethod: .cashOnDelivery
        )

        XCTAssertTrue(order.paymentMethod.isCollectOnDelivery)
        XCTAssertEqual(order.paymentMethod.title, "Bar bei Lieferung")
        XCTAssertEqual(order.formattedTotal, "24,50 €")
    }

    func testTransitDurationCalculation() {
        let now = Date()
        let order = KitchenLinkDeliveryOrder(
            orderNumber: "L-201",
            recipientName: "Test",
            address: KitchenLinkDeliveryAddress(street: "Test", houseNumber: "1", postalCode: "10115", city: "Berlin"),
            itemsSummary: "Pizza",
            totalCents: 2000,
            status: .outForDelivery,
            dispatchedAt: now.addingTimeInterval(-15 * 60)
        )

        let duration = order.transitDurationMinutes
        XCTAssertNotNil(duration)
        XCTAssertGreaterThanOrEqual(duration ?? 0, 14)
        XCTAssertLessThanOrEqual(duration ?? 0, 16)
    }
}
