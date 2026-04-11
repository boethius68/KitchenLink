import Testing
@testable import kitchenlink

struct OrderingDomainTests {

    private let demoVenue = VenueProfile(
        id: "venue-test",
        name: "Test Venue",
        slug: "test-venue",
        supportedServiceModes: [.dineIn, .bar, .pickup],
        tables: [
            VenueTable(id: "table-a1", label: "A1", isActive: true),
            VenueTable(id: "table-a2", label: "A2", isActive: true),
            VenueTable(id: "table-c1", label: "C1", isActive: false)
        ]
    )

    @Test
    func dineInRequiresValidTableCodeForSharedQR() {
        let context = ResolvedVenueContext(
            token: "shared",
            venue: demoVenue,
            mode: .venueShared,
            resolvedTable: nil
        )

        var checkout = CheckoutState(context: context)
        checkout.serviceMode = .dineIn
        checkout.manualTableCode = ""

        let result = checkout.validated(in: context)

        #expect(result == .failure(.missingTable))
    }

    @Test
    func dineInAcceptsKnownActiveTableCode() throws {
        let context = ResolvedVenueContext(
            token: "shared",
            venue: demoVenue,
            mode: .venueShared,
            resolvedTable: nil
        )

        var checkout = CheckoutState(context: context)
        checkout.serviceMode = .dineIn
        checkout.manualTableCode = "a2"

        let result = checkout.validated(in: context)
        let confirmed = try result.get()

        #expect(confirmed.table?.label == "A2")
        #expect(confirmed.serviceMode == .dineIn)
    }

    @Test
    func barOrderDoesNotNeedTable() throws {
        let context = ResolvedVenueContext(
            token: "shared",
            venue: demoVenue,
            mode: .venueShared,
            resolvedTable: nil
        )

        var checkout = CheckoutState(context: context)
        checkout.serviceMode = .bar

        let result = checkout.validated(in: context)
        let confirmed = try result.get()

        #expect(confirmed.table == nil)
        #expect(confirmed.serviceMode == .bar)
    }

    @Test
    func tableQRPreselectsResolvedTable() throws {
        let context = ResolvedVenueContext(
            token: "table",
            venue: demoVenue,
            mode: .table,
            resolvedTable: demoVenue.tables.first(where: { $0.label == "A1" })
        )

        let checkout = CheckoutState(context: context)
        let confirmed = try checkout.validated(in: context).get()

        #expect(confirmed.table?.label == "A1")
        #expect(confirmed.serviceMode == .dineIn)
    }

    @Test
    func orderStatusTransitionsStayStrict() {
        #expect(OrderLifecycleStatus.pending.canTransition(to: .accepted))
        #expect(!OrderLifecycleStatus.pending.canTransition(to: .ready))
        #expect(OrderLifecycleStatus.preparing.canTransition(to: .canceled))
        #expect(!OrderLifecycleStatus.served.canTransition(to: .canceled))
    }
}
