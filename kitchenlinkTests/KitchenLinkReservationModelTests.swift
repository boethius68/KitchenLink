import XCTest
@testable import kitchenlink

final class KitchenLinkReservationModelTests: XCTestCase {

    func testLoadReservationsForToday() async throws {
        let provider = KitchenLinkReservationsDemoProvider()
        let today = KitchenLinkReservationDateHelper.todayDateString()
        let list = try await provider.loadReservations(date: today)

        XCTAssertFalse(list.isEmpty)
        XCTAssertEqual(list.count, 3)
        XCTAssertEqual(list[0].guestName, "Familie Sommer")
        XCTAssertEqual(list[0].partySize, 4)
        XCTAssertEqual(list[0].status, .confirmed)
    }

    func testUpdateStatusAndSeatParty() async throws {
        let provider = KitchenLinkReservationsDemoProvider()
        let today = KitchenLinkReservationDateHelper.todayDateString()

        // Familie Sommer platzieren auf Tisch 5
        try await provider.updateStatus(reservationID: "demo-res-1", status: .seated, tableID: "5")

        let list = try await provider.loadReservations(date: today)
        let updated = try XCTUnwrap(list.first { $0.id == "demo-res-1" })

        XCTAssertEqual(updated.status, .seated)
        XCTAssertEqual(updated.tableID, "5")
        XCTAssertEqual(updated.tableLabel, "Tisch 5")
    }

    func testCompleteReservation() async throws {
        let provider = KitchenLinkReservationsDemoProvider()
        let today = KitchenLinkReservationDateHelper.todayDateString()

        // Dr. Weber Besuch abschließen
        try await provider.updateStatus(reservationID: "demo-res-2", status: .completed, tableID: nil)

        let list = try await provider.loadReservations(date: today)
        let updated = try XCTUnwrap(list.first { $0.id == "demo-res-2" })

        XCTAssertEqual(updated.status, .completed)
        XCTAssertTrue(updated.status.isTerminal)
    }

    func testUpdateNonExistentReservationThrows() async {
        let provider = KitchenLinkReservationsDemoProvider()

        do {
            try await provider.updateStatus(reservationID: "invalid-id", status: .completed, tableID: nil)
            XCTFail("Should have thrown error")
        } catch let error as KitchenLinkReservationError {
            switch error {
            case .notFound:
                break // Success
            default:
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCreatePhoneReservation() async throws {
        let provider = KitchenLinkReservationsDemoProvider()
        let today = KitchenLinkReservationDateHelper.todayDateString()

        let created = try await provider.createPhoneReservation(
            guestName: "Maria Lindner",
            guestEmail: "maria.lindner@test.de",
            guestPhone: "+49176123456",
            partySize: 6,
            date: today,
            time: "19:30",
            area: "Terrasse",
            specialRequests: "Terrassentisch mit Seeblick"
        )

        XCTAssertTrue(created.referenceCode.hasPrefix("KL-"))
        XCTAssertEqual(created.guestName, "Maria Lindner")
        XCTAssertEqual(created.partySize, 6)
        XCTAssertEqual(created.status, .confirmed)
        XCTAssertEqual(created.area, "Terrasse")

        // In Liste auffindbar
        let list = try await provider.loadReservations(date: today)
        XCTAssertTrue(list.contains { $0.id == created.id })
    }

    func testCreatePhoneReservationValidatesInputs() async {
        let provider = KitchenLinkReservationsDemoProvider()
        let today = KitchenLinkReservationDateHelper.todayDateString()

        // Name zu kurz
        do {
            _ = try await provider.createPhoneReservation(
                guestName: "A",
                guestEmail: "test@test.de",
                guestPhone: nil,
                partySize: 2,
                date: today,
                time: "18:00",
                area: "Gastraum",
                specialRequests: nil
            )
            XCTFail("Short name should throw")
        } catch {}

        // Personenanzahl 0
        do {
            _ = try await provider.createPhoneReservation(
                guestName: "Test Person",
                guestEmail: "test@test.de",
                guestPhone: nil,
                partySize: 0,
                date: today,
                time: "18:00",
                area: "Gastraum",
                specialRequests: nil
            )
            XCTFail("Party size 0 should throw")
        } catch {}
    }

    func testDateHelpers() {
        let today = KitchenLinkReservationDateHelper.todayDateString()
        let tomorrow = KitchenLinkReservationDateHelper.tomorrowDateString()

        XCTAssertTrue(today.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil)
        XCTAssertTrue(tomorrow.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil)
        XCTAssertNotEqual(today, tomorrow)

        let formatted = KitchenLinkReservationDateHelper.formattedGermanDate("2026-10-24")
        XCTAssertFalse(formatted.isEmpty)
    }
}
