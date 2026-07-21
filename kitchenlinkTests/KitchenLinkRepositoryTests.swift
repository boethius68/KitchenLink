import Foundation
import Testing
@testable import kitchenlink

struct KitchenLinkRepositoryTests {

    @Test
    func localRepositoryPersistsMenuSections() throws {
        let defaults = try isolatedDefaults()
        let repository = LocalDemoRepository(defaults: defaults)
        let sections = [
            MenuSectionData(
                id: "section-drinks",
                title: "Drinks",
                subtitle: "Hausgemacht",
                kind: .drink,
                items: [
                    MenuItemData(
                        id: "item-spritz",
                        name: "Kitchen Spritz",
                        description: "Mit Orange und Soda",
                        priceCents: 850,
                        kind: .drink,
                        variants: [
                            MenuItemVariant(id: "variant-large", name: "Groß", priceCents: 200, kind: .portion)
                        ],
                        allergenCodes: "13",
                        priceBasis: "per_item"
                    )
                ],
                importConfidence: 0.9,
                allergenLegend: ["13": "alkoholhaltig"]
            )
        ]

        try repository.saveMenuSections(sections)
        let loadedSections = repository.loadMenuSections(fallback: [])

        #expect(loadedSections.count == 1)
        #expect(loadedSections.first?.title == "Drinks")
        #expect(loadedSections.first?.items.count == 1)
        #expect(loadedSections.first?.items.first?.name == "Kitchen Spritz")
        #expect(loadedSections.first?.items.first?.variants.first?.name == "Groß")
        #expect(loadedSections.first?.items.first?.priceBasis == "per_item")
    }

    @Test
    func localRepositoryPersistsVenueProfile() throws {
        let defaults = try isolatedDefaults()
        let repository = LocalDemoRepository(defaults: defaults)
        let venue = VenueProfile(
            id: UUID().uuidString.lowercased(),
            name: "Repo Venue",
            slug: "repo-venue",
            supportedServiceModes: [.dineIn, .bar],
            tables: [
                VenueTable(id: UUID().uuidString.lowercased(), label: "A1", isActive: true)
            ]
        )

        try repository.saveVenueProfile(venue)
        let loadedVenue = repository.loadVenueProfile(fallback: VenueProfile(
            id: UUID().uuidString.lowercased(),
            name: "Fallback",
            slug: "fallback",
            supportedServiceModes: [.pickup],
            tables: []
        ))

        #expect(loadedVenue == venue)
    }

    @Test
    func localRepositoryResolvesSharedAndTableQRCodes() throws {
        let defaults = try isolatedDefaults()
        let repository = LocalDemoRepository(defaults: defaults)
        let venue = VenueProfile(
            id: UUID().uuidString.lowercased(),
            name: "Repo Venue",
            slug: "repo-venue",
            supportedServiceModes: [.dineIn, .bar],
            tables: [
                VenueTable(id: UUID().uuidString.lowercased(), label: "A1", isActive: true)
            ]
        )

        let sharedCode = "kitchenlink://venue/repo-venue/shared"
        let tableCode = "kitchenlink://table/repo-venue/A1"

        let sharedContext = repository.resolveQRCode(sharedCode, venue: venue)
        let tableContext = repository.resolveQRCode(tableCode, venue: venue)

        #expect(sharedContext?.mode == .venueShared)
        #expect(sharedContext?.resolvedTable == nil)
        #expect(tableContext?.mode == .table)
        #expect(tableContext?.resolvedTable?.label == "A1")
    }

    @Test
    func localRepositoryRoundTripsOrdersAndStatusUpdates() throws {
        let defaults = try isolatedDefaults()
        let repository = LocalDemoRepository(defaults: defaults)
        let order = LiveOrderMessage(
            id: UUID().uuidString.lowercased(),
            createdAt: .now,
            sourceDevice: "Test iPhone",
            venueID: UUID().uuidString.lowercased(),
            venueName: "Repo Venue",
            serviceMode: .dineIn,
            tableID: UUID().uuidString.lowercased(),
            tableLabel: "A1",
            customerNote: "Ohne Eis",
            items: [
                LiveOrderLine(
                    id: UUID().uuidString.lowercased(),
                    name: "Hauslimonade",
                    quantity: 2,
                    unitPriceCents: 450,
                    kind: .drink
                )
            ],
            totalCents: 900,
            status: .pending
        )

        let storedOrder = try repository.createOrder(order)
        let loadedOrders = try repository.loadOrders()
        let updatedOrder = try repository.updateOrderStatus(orderID: storedOrder.id, to: .accepted)

        #expect(loadedOrders.count == 1)
        #expect(loadedOrders.first?.id == storedOrder.id)
        #expect(updatedOrder?.status == .accepted)
        #expect(try repository.loadOrder(orderID: storedOrder.id)?.status == .accepted)
    }

    @Test
    func menuItemAllergenCodesRoundTripThroughCSVString() {
        // Simulates the mapping done in OrderRelayService when loading from Supabase:
        // allergen_codes (text[]) → joined CSV string → stored in MenuItemData.allergenCodes
        let remoteAllergenCodes = ["a", "c", "g"]
        let csvString = remoteAllergenCodes.joined(separator: ",")

        let item = MenuItemData(
            id: "item-test",
            name: "Test Artikel",
            description: "Testbeschreibung",
            priceCents: 500,
            kind: .food,
            allergenCodes: csvString
        )

        // Verify the CSV round-trip is stable
        #expect(item.allergenCodes == "a,c,g")
        #expect(item.resolvedAllergenCodes == "a,c,g")

        // Simulates mapping back to Supabase array (as done in upsertRemoteMenuItem)
        let backToArray = (item.allergenCodes ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        #expect(backToArray == ["a", "c", "g"])
    }

    @Test
    func menuSectionDataPreservesAllergenLegendRoundTrip() throws {
        let defaults = try isolatedDefaults()
        let repository = LocalDemoRepository(defaults: defaults)

        let legend = ["a": "Gluten", "b": "Krebstiere"]
        let section = MenuSectionData(
            id: "section-food",
            title: "Hauptgericht",
            subtitle: "Küche",
            kind: .food,
            items: [
                MenuItemData(
                    id: "item-pasta",
                    name: "Pasta",
                    description: "Al dente",
                    priceCents: 1200,
                    kind: .food,
                    allergenCodes: "a,b"
                )
            ],
            importConfidence: 1.0,
            allergenLegend: legend
        )

        try repository.saveMenuSections([section])
        let loaded = repository.loadMenuSections(fallback: [])

        #expect(loaded.count == 1)
        #expect(loaded.first?.allergenLegend?["a"] == "Gluten")
        #expect(loaded.first?.allergenLegend?["b"] == "Krebstiere")
        #expect(loaded.first?.items.first?.allergenCodes == "a,b")
    }

    private func isolatedDefaults() throws -> UserDefaults {
        let suiteName = "KitchenLinkRepositoryTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw TestFailure("Could not create isolated UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
