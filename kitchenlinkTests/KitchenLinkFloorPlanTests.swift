import XCTest
@testable import kitchenlink

final class KitchenLinkFloorPlanTests: XCTestCase {

    func testLoadFloorPlanTables() async throws {
        let provider = KitchenLinkFloorPlanDemoProvider()
        let tables = try await provider.loadFloorPlan()

        XCTAssertEqual(tables.count, 8)

        let table1 = try XCTUnwrap(tables.first { $0.id == "table-1" })
        XCTAssertTrue(table1.occupancy.isOccupied)
        XCTAssertEqual(table1.label, "1")
        XCTAssertEqual(table1.seats, 4)

        let table3 = try XCTUnwrap(tables.first { $0.id == "table-3" })
        XCTAssertTrue(table3.occupancy.isReserved)

        let table4 = try XCTUnwrap(tables.first { $0.id == "table-4" })
        XCTAssertTrue(table4.occupancy.isFree)
    }

    func testTransferTableSession() async throws {
        let provider = KitchenLinkFloorPlanDemoProvider()

        // Tisch 1 (belegt, 42,50 €) auf Tisch 4 (frei) umsetzen
        try await provider.transferSession(fromTableID: "table-1", toTableID: "table-4")

        let tables = try await provider.loadFloorPlan()
        let table1 = try XCTUnwrap(tables.first { $0.id == "table-1" })
        let table4 = try XCTUnwrap(tables.first { $0.id == "table-4" })

        XCTAssertTrue(table1.occupancy.isFree)
        XCTAssertTrue(table4.occupancy.isOccupied)

        if case .occupied(_, _, let orderCount, let totalCents) = table4.occupancy {
            XCTAssertEqual(orderCount, 3)
            XCTAssertEqual(totalCents, 4250)
        } else {
            XCTFail("Table 4 must be occupied after transfer")
        }
    }

    func testTransferSessionValidation() async {
        let provider = KitchenLinkFloorPlanDemoProvider()

        // Transfer von freiem Tisch (Tisch 4) schlägt fehl
        do {
            try await provider.transferSession(fromTableID: "table-4", toTableID: "table-5")
            XCTFail("Transfer from free table must fail")
        } catch let error as KitchenLinkFloorPlanError {
            switch error {
            case .invalidOperation:
                break // Success
            default:
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // Transfer auf bereits belegten Tisch (Tisch 1 auf Tisch 2) schlägt fehl
        do {
            try await provider.transferSession(fromTableID: "table-1", toTableID: "table-2")
            XCTFail("Transfer to occupied table must fail")
        } catch let error as KitchenLinkFloorPlanError {
            switch error {
            case .invalidOperation:
                break // Success
            default:
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMergeTables() async throws {
        let provider = KitchenLinkFloorPlanDemoProvider()

        // Tisch 2 (18,00 €, 2 Orders) in Tisch 1 (42,50 €, 3 Orders) zusammenlegen
        try await provider.mergeTables(sourceTableID: "table-2", targetTableID: "table-1")

        let tables = try await provider.loadFloorPlan()
        let table1 = try XCTUnwrap(tables.first { $0.id == "table-1" })
        let table2 = try XCTUnwrap(tables.first { $0.id == "table-2" })

        XCTAssertTrue(table2.occupancy.isFree)
        XCTAssertTrue(table1.occupancy.isOccupied)

        if case .occupied(_, _, let orderCount, let totalCents) = table1.occupancy {
            XCTAssertEqual(orderCount, 5) // 3 + 2
            XCTAssertEqual(totalCents, 6050) // 4250 + 1800
        } else {
            XCTFail("Table 1 must have combined orders and totals")
        }
    }
}
