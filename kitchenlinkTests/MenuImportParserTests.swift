import Testing
@testable import kitchenlink

struct MenuImportParserTests {
    @Test func wholeEuroPricesRequireCurrencyContext() {
        #expect(MenuImportService.parsePriceOnly(from: "28 EUR") == 2_800)
        #expect(MenuImportService.parsePriceOnly(from: "28") == nil)

        let item = MenuImportService.parseInlineItem(
            from: "Ueberraschungsmenue 3 - gang 55 EUR"
        )
        #expect(item?.0 == "Ueberraschungsmenue 3 - gang")
        #expect(item?.1 == 5_500)
        #expect(MenuImportService.parseInlineItem(from: "Tisch 12") == nil)
    }

    @Test func quantityCanRemainPartOfAnItemTitle() {
        #expect(
            MenuImportService.isLikelyItemTitleLine(
                "Hueftsteak(250gr)",
                hasAlignedPrice: false
            )
        )
        #expect(
            !MenuImportService.isLikelyItemTitleLine(
                "# auf Wunsch mit Bratkartoffeln",
                hasAlignedPrice: false
            )
        )
    }

    @Test func menuBundlesUseAGenericHeadingRule() {
        #expect(MenuImportService.isKnownSectionHeading("Menue des Hauses"))
        #expect(MenuImportService.isKnownSectionHeading("Ueberraschungsmenue 3 - gang"))
        #expect(!MenuImportService.isKnownSectionHeading("Menuepreis pro Person"))
    }
}
