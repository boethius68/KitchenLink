import Testing
import UIKit
@testable import kitchenlink

struct FoodDeclarationCatalogTests {
    /// Hält die SF-Symbol-Fälle aus `FoodDeclarationGlyphView` nachweisbar
    /// renderbar. Ein nicht existierender Name (wie früher `jar.fill` für
    /// die Konservierungsstoff-Kennzeichnung) bliebe sonst still als leeres
    /// Badge unsichtbar — für Pflichtkennzeichnungen inakzeptabel.
    @Test func everySystemSymbolGlyphResolvesToARealSFSymbol() {
        let usedSystemSymbols = [
            "cup.and.saucer.fill", "paintpalette.fill", "shield.lefthalf.filled",
            "wave.3.up", "circle.lefthalf.filled", "sparkles", "cube.fill",
            "takeoutbag.and.cup.and.straw.fill", "hurricane", "wineglass.fill",
            "text.bubble.fill", "questionmark"
        ]
        for name in usedSystemSymbols {
            #expect(UIImage(systemName: name) != nil, "SF Symbol \(name) existiert nicht")
        }
    }
    @Test func guestMenuHierarchyKeepsTheDishNamePrimary() {
        #expect(
            KitchenLinkV2GuestMenuMetrics.itemTitlePointSize
                > KitchenLinkV2GuestMenuMetrics.itemPricePointSize
        )
        #expect(KitchenLinkV2GuestMenuMetrics.declarationVisualSize <= 22)
        #expect(KitchenLinkV2GuestMenuMetrics.minimumTapTarget >= 44)
    }

    /// Gesetzliche Vorgabe: Kennzeichnungen dürfen in der Gastkarte nicht auf
    /// wenige Symbole gekürzt werden. Der Katalog muss deshalb für ein voll
    /// deklariertes Gericht jede Angabe einzeln liefern; die Darstellung
    /// bricht um, statt zu kürzen.
    @Test func fullyDeclaredDishResolvesEveryDeclaration() {
        let codes = "a,b,c,d,e,f,g,h,i,j,k,l,m,n,farbstoff,konserviert,geschmacksverstaerker,phosphat,koffeinhaltig,13"
        let definitions = AllergenCatalog.definitions(for: codes)
        #expect(definitions.count == 20)
        #expect(Set(definitions.map(\.code)).count == 20)
    }

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
