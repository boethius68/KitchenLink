import Testing
@testable import kitchenlink

struct FoodDeclarationCatalogTests {
    @Test func catalogContainsExactlyFourteenEUAllergens() {
        #expect(AllergenCatalog.standardAllergens.count == 14)
        #expect(AllergenCatalog.standardAllergens.map(\.code) == "abcdefghijklmn".map(String.init))
        #expect(!AllergenCatalog.standardAllergens.contains { $0.title.contains("Knoblauch") || $0.title.contains("Zwiebel") })
    }

    @Test func catalogSeparatesLooseFoodAdditivesAndConsumerNotices() {
        #expect(AllergenCatalog.standardAdditives.count == 14)
        #expect(AllergenCatalog.standardAdditives.allSatisfy { $0.group == .additive })
        #expect(AllergenCatalog.additionalNotices.contains { $0.code == "chininhaltig" })
        #expect(AllergenCatalog.additionalNotices.contains { $0.code == "koffeinwarnung" })
    }

    @Test func sourceLegendDeterminesMeaningInsteadOfNumericLegacyCode() {
        let result = AllergenCatalog.definitions(
            for: "1",
            customTitles: ["1": "Milch und Laktose"]
        )
        #expect(result.first?.code == "1")
        #expect(result.first?.title == "Milch und Laktose")
        #expect(result.first?.glyph == .milk)
        #expect(result.first?.group == .allergen)
    }

    @Test func frequentAllergensAreShownFirst() {
        let result = AllergenCatalog.definitions(for: "i,c,g,a")
        #expect(result.map(\.code) == ["a", "g", "c", "i"])
    }

    @Test func alcoholUsesARecognizableDedicatedGlyph() {
        let legacy = AllergenCatalog.definitions(for: "13")
        let sourceLegend = AllergenCatalog.definitions(
            for: "x",
            customTitles: ["x": "mit Alkohol"]
        )
        let polyols = AllergenCatalog.definitions(
            for: "y",
            customTitles: ["y": "mehrwertige Alkohole"]
        )

        #expect(legacy.first?.glyph == .alcohol)
        #expect(sourceLegend.first?.glyph == .alcohol)
        #expect(sourceLegend.first?.title == "mit Alkohol")
        #expect(polyols.first?.glyph == .polyols)
    }

    @Test func concreteENumberGetsNeutralAdditiveIcon() {
        let result = AllergenCatalog.definitions(for: "E621")
        #expect(result.first?.code == "e621")
        #expect(result.first?.glyph == .genericAdditive)
        #expect(result.first?.group == .additive)
    }

    @Test func houseCodeFromLegendRemainsVisible() {
        let result = AllergenCatalog.definitions(
            for: "haus1",
            customTitles: ["haus1": "Knoblauch nach Hausrezept"]
        )
        #expect(result.first?.code == "haus1")
        #expect(result.first?.title == "Knoblauch nach Hausrezept")
        #expect(result.first?.group == .sourceNotice)
    }
}
