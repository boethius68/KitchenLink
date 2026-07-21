import Testing
@testable import kitchenlink

struct DemoMenuFixturesTests {
    @Test func appOffersExactlyThreeComplementaryFixtures() {
        #expect(DemoMenuFixtures.selectable.count == 3)
        #expect(Set(DemoMenuFixtures.selectable.map(\.id)).count == 3)

        let covered = Set(DemoMenuFixtures.selectable.flatMap(\.coverage))
        let required: Set<DemoMenuCapability> = [
            .allergens,
            .additives,
            .categories,
            .descriptions,
            .foodAndDrinks,
            .variants,
            .setMenu,
            .bilingual,
            .denseLayout,
        ]
        #expect(required.isSubset(of: covered))
    }

    @Test func deterministicFixtureDeclaresTheFullStructuredScope() {
        let fixture = DemoMenuFixtures.kitchenLinkTestRestaurant
        #expect(fixture.isSynthetic)
        #expect(fixture.pageCount == 3)
        #expect(fixture.coverage.contains(.allergens))
        #expect(fixture.coverage.contains(.additives))
        #expect(fixture.coverage.contains(.foodAndDrinks))
        #expect(fixture.coverage.contains(.variants))
        #expect(fixture.coverage.contains(.setMenu))
        #expect(DemoMenuFixtures.images(for: fixture).count == fixture.pageCount)
    }
}
