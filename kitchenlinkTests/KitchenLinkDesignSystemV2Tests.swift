import Testing
@testable import kitchenlink

struct KitchenLinkDesignSystemV2Tests {

    @Test
    func primaryActionUsesAccessibleGrapeOnLemonContrast() {
        let grape = KitchenLinkV2Palette.RGB(hex: 0x2C2438)
        let lemon = KitchenLinkV2Palette.RGB(hex: 0xB6CC1B)

        #expect(grape.contrastRatio(against: lemon) >= 4.5)
    }

    @Test
    func primaryTextRemainsAccessibleOnLightAndDarkBaseSurfaces() {
        let lightBase = KitchenLinkV2Palette.RGB(hex: 0xF4F2F8)
        let darkBase = KitchenLinkV2Palette.RGB(hex: 0x221B2E)
        let lightText = KitchenLinkV2Palette.RGB(hex: 0x2C2438)
        let darkText = KitchenLinkV2Palette.RGB(hex: 0xF1EFF7)

        #expect(lightText.contrastRatio(against: lightBase) >= 4.5)
        #expect(darkText.contrastRatio(against: darkBase) >= 4.5)
    }

    @Test
    func kitchenBumpButtonStaysAccessibleInAllStates() {
        let ticketSurface = KitchenLinkV2Palette.RGB(hex: 0x2C2438)
        let grapeText = KitchenLinkV2Palette.RGB(hex: 0x2C2438)
        let restingFill = KitchenLinkV2Palette.RGB(hex: 0xF1EFF7)
        let pressedFill = KitchenLinkV2Palette.RGB(hex: 0xD9D3E6)

        // Text stays readable while resting and pressed.
        #expect(grapeText.contrastRatio(against: restingFill) >= 4.5)
        #expect(grapeText.contrastRatio(against: pressedFill) >= 4.5)

        // The control itself stands out clearly against the dark ticket.
        #expect(restingFill.contrastRatio(against: ticketSurface) >= 3.0)
        #expect(pressedFill.contrastRatio(against: ticketSurface) >= 3.0)
    }

    @Test
    func urgencySymbolsKeepThreeToOneOnTheirSurfaces() {
        // Round 04 board 6a: every meaning-bearing status shape stays >= 3:1
        // against the surface it appears on, checked per light and dark role.
        let lightSurface = KitchenLinkV2Palette.RGB(hex: 0xF4F2F8)
        let lightSymbols = [0x2E8F5A, 0x6E6880, 0xA97512, 0xB3261E]
            .map { KitchenLinkV2Palette.RGB(hex: $0) }

        for symbol in lightSymbols {
            #expect(symbol.contrastRatio(against: lightSurface) >= 3.0)
        }

        let darkSurfaces = [0x2C2438, 0x221B2E, 0x383048]
            .map { KitchenLinkV2Palette.RGB(hex: $0) }
        let darkSymbols = [0x3FA96D, 0x9A94AE, 0xD79A2A, 0xEF6E64]
            .map { KitchenLinkV2Palette.RGB(hex: $0) }

        for surface in darkSurfaces {
            for symbol in darkSymbols {
                #expect(symbol.contrastRatio(against: surface) >= 3.0)
            }
        }
    }
}
