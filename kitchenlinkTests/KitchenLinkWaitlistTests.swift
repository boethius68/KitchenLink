import XCTest
@testable import kitchenlink

final class KitchenLinkWaitlistTests: XCTestCase {

    func testLoadActiveWaitlist() async throws {
        let provider = KitchenLinkWaitlistDemoProvider()
        let active = try await provider.loadWaitlist()

        XCTAssertEqual(active.count, 2)
        XCTAssertEqual(active[0].guestName, "Markus Bauer")
        XCTAssertEqual(active[0].partySize, 2)
        XCTAssertEqual(active[0].status, .waiting)

        XCTAssertEqual(active[1].guestName, "Sarah Neumann")
        XCTAssertEqual(active[1].partySize, 4)
        XCTAssertEqual(active[1].status, .notified)
    }

    func testAddWalkInToWaitlist() async throws {
        let provider = KitchenLinkWaitlistDemoProvider()

        let created = try await provider.addWalkIn(
            guestName: "Tobias Schmidt",
            partySize: 3,
            phone: "+491712345678",
            area: "Terrasse",
            estimatedWaitMinutes: 25,
            notes: "Draußen bevorzugt"
        )

        XCTAssertEqual(created.guestName, "Tobias Schmidt")
        XCTAssertEqual(created.partySize, 3)
        XCTAssertEqual(created.status, .waiting)
        XCTAssertEqual(created.estimatedWaitMinutes, 25)
        XCTAssertEqual(created.area, "Terrasse")

        let active = try await provider.loadWaitlist()
        XCTAssertTrue(active.contains { $0.id == created.id })
    }

    func testWalkInValidation() async {
        let provider = KitchenLinkWaitlistDemoProvider()

        do {
            _ = try await provider.addWalkIn(
                guestName: " ",
                partySize: 2,
                phone: nil,
                area: "Gastraum",
                estimatedWaitMinutes: 15,
                notes: nil
            )
            XCTFail("Empty name must throw")
        } catch let error as KitchenLinkWaitlistError {
            switch error {
            case .invalidInput:
                break // Success
            default:
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            _ = try await provider.addWalkIn(
                guestName: "Valid Name",
                partySize: 0,
                phone: nil,
                area: "Gastraum",
                estimatedWaitMinutes: 15,
                notes: nil
            )
            XCTFail("Zero party size must throw")
        } catch {}
    }

    func testNotifyAndSeatWaitlistGuests() async throws {
        let provider = KitchenLinkWaitlistDemoProvider()

        // 1. Benachrichtigen
        try await provider.updateStatus(entryID: "wait-1", status: .notified, tableID: nil)

        var list = try await provider.loadWaitlist()
        let notified = try XCTUnwrap(list.first { $0.id == "wait-1" })
        XCTAssertEqual(notified.status, .notified)

        // 2. Platzieren auf Tisch 7
        try await provider.updateStatus(entryID: "wait-1", status: .seated, tableID: "7")

        // Platzierte Gäste verlassen die aktive Warteliste
        list = try await provider.loadWaitlist()
        XCTAssertFalse(list.contains { $0.id == "wait-1" })
    }

    func testCancelWaitlistEntry() async throws {
        let provider = KitchenLinkWaitlistDemoProvider()

        try await provider.updateStatus(entryID: "wait-2", status: .cancelled, tableID: nil)

        let list = try await provider.loadWaitlist()
        XCTAssertFalse(list.contains { $0.id == "wait-2" })
    }

    func testElapsedAndOverdueCalculations() {
        let now = Date()
        let created20MinAgo = now.addingTimeInterval(-1200)

        let entry = KitchenLinkWaitlistEntry(
            guestName: "Test",
            partySize: 2,
            estimatedWaitMinutes: 15,
            createdAt: created20MinAgo
        )

        XCTAssertEqual(entry.elapsedMinutes(at: now), 20)
        XCTAssertTrue(entry.isOverdue(at: now))

        let entryFresh = KitchenLinkWaitlistEntry(
            guestName: "Fresh",
            partySize: 2,
            estimatedWaitMinutes: 15,
            createdAt: now.addingTimeInterval(-300)
        )
        XCTAssertEqual(entryFresh.elapsedMinutes(at: now), 5)
        XCTAssertFalse(entryFresh.isOverdue(at: now))
    }

    func testSeatingTurnoverHelper() {
        let seatedAt = Date()
        let departure = KitchenLinkSeatingTurnoverHelper.expectedDepartureDate(seatedAt: seatedAt, durationMinutes: 90)

        let diff = departure.timeIntervalSince(seatedAt)
        XCTAssertEqual(diff, 90 * 60)

        let remaining = KitchenLinkSeatingTurnoverHelper.remainingMinutes(
            seatedAt: seatedAt,
            durationMinutes: 90,
            now: seatedAt.addingTimeInterval(30 * 60)
        )
        XCTAssertEqual(remaining, 60)
    }
}
