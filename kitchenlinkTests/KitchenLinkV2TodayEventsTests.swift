import Foundation
import Testing
@testable import kitchenlink

struct KitchenLinkV2TodayEventsTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test
    func pendingOrderBecomesFreshOrderEvent() throws {
        let event = try #require(
            KitchenLinkV2TodayEventBuilder.event(
                from: order(status: .pending, ageSeconds: 12, tableLabel: "A1"),
                now: now
            )
        )

        #expect(event.status.operation == .order)
        #expect(event.status.urgency == .fresh)
        #expect(event.title == "Tisch A1 · neue Bestellung")
        #expect(event.trailing == .elapsed(12))
        #expect(event.trailing.text == "0:12")
        #expect(event.nextActionTitle == "Annehmen")
    }

    @Test
    func overdueKitchenOrderTurnsWaitingWithOverdueTime() throws {
        let event = try #require(
            KitchenLinkV2TodayEventBuilder.event(
                from: order(status: .preparing, ageSeconds: 9 * 60, tableLabel: "B1"),
                now: now
            )
        )

        #expect(event.status.operation == .order)
        #expect(event.status.urgency == .waiting)
        #expect(event.status.verb == "Küche wartet")
        #expect(event.trailing == .overdue(3 * 60))
        #expect(event.trailing.text == "+3:00")
    }

    @Test
    func servedOrderBecomesNeutralOpenPayment() throws {
        let event = try #require(
            KitchenLinkV2TodayEventBuilder.event(
                from: order(
                    status: .served,
                    ageSeconds: 14 * 60,
                    tableLabel: "A2",
                    totalCents: 6_840
                ),
                now: now
            )
        )

        #expect(event.status.operation == .payment)
        #expect(event.status.urgency == .neutral)
        #expect(event.status.verb == "Zahlung offen")
        #expect(event.trailing == .amount(cents: 6_840))
        #expect(event.trailing.text == "€ 68,40")
        #expect(event.nextActionTitle == nil)
    }

    @Test
    func canceledOrdersAreExcludedFromTheWorkList() {
        let events = KitchenLinkV2TodayEventBuilder.events(
            from: [order(status: .canceled, ageSeconds: 60, tableLabel: "C1")],
            now: now
        )

        #expect(events.isEmpty)
    }

    @Test
    func nextActionPrefersTheMostUrgentActionableEvent() throws {
        let events = KitchenLinkV2TodayEventBuilder.events(
            from: [
                order(id: "fresh", status: .pending, ageSeconds: 10, tableLabel: "A1"),
                order(id: "payment", status: .served, ageSeconds: 900, tableLabel: "A2"),
                order(id: "late", status: .preparing, ageSeconds: 9 * 60, tableLabel: "B1")
            ],
            now: now
        )

        #expect(events.first?.id == "late")
        let nextAction = try #require(KitchenLinkV2TodayEventBuilder.nextAction(in: events))
        #expect(nextAction.id == "late")
        #expect(nextAction.nextActionTitle == "Als bereit markieren")
    }

    @Test
    func kitchenTicketKeepsNoteAsChangeInformation() throws {
        let ticket = try #require(
            KitchenLinkV2KitchenTicket.ticket(
                from: order(
                    status: .preparing,
                    ageSeconds: 60,
                    tableLabel: "B1",
                    customerNote: "Bitte ohne Ei"
                ),
                now: now
            )
        )

        #expect(ticket.note == "Bitte ohne Ei")
        #expect(ticket.status.urgency == .neutral)
        #expect(ticket.itemLines == ["2× Schnitzel"])
        #expect(ticket.advanceActionTitle == "Als bereit markieren")
    }

    @Test
    func servedKitchenTicketShowsNeutralOpenPaymentAmount() throws {
        let ticket = try #require(
            KitchenLinkV2KitchenTicket.ticket(
                from: order(
                    status: .served,
                    ageSeconds: 600,
                    tableLabel: "B2",
                    totalCents: 4_210
                ),
                now: now
            )
        )

        #expect(ticket.status.operation == .payment)
        #expect(ticket.status.urgency == .neutral)
        #expect(ticket.trailingText == "€ 42,10")
        #expect(ticket.advanceActionTitle == nil)
    }

    private func order(
        id: String = UUID().uuidString,
        status: OrderLifecycleStatus,
        ageSeconds: TimeInterval,
        tableLabel: String?,
        totalCents: Int = 2_280,
        customerNote: String = ""
    ) -> LiveOrderMessage {
        LiveOrderMessage(
            id: id,
            createdAt: now.addingTimeInterval(-ageSeconds),
            sourceDevice: "Test",
            venueID: "venue-test",
            venueName: "Testhaus",
            serviceMode: .dineIn,
            tableID: tableLabel,
            tableLabel: tableLabel,
            customerNote: customerNote,
            items: [
                LiveOrderLine(
                    id: "line-1",
                    name: "Schnitzel",
                    quantity: 2,
                    unitPriceCents: 1_140,
                    kind: .food
                )
            ],
            totalCents: totalCents,
            status: status
        )
    }
}
