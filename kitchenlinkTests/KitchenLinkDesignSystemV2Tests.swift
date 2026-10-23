import Testing
@testable import kitchenlink

struct KitchenLinkDesignSystemV2Tests {

    @Test
    func primaryActionUsesAccessibleCarbonOnLemonContrast() {
        let textOnLemon = KitchenLinkV2Palette.RGB(hex: 0x17171B)
        let lemon = KitchenLinkV2Palette.RGB(hex: 0xB6CC1B)

        #expect(textOnLemon.contrastRatio(against: lemon) >= 4.5)
    }

    @Test
    func primaryTextRemainsAccessibleOnLightAndDarkBaseSurfaces() {
        let lightBase = KitchenLinkV2Palette.RGB(hex: 0xF4F4F1)
        let darkBase = KitchenLinkV2Palette.RGB(hex: 0x121215)
        let lightText = KitchenLinkV2Palette.RGB(hex: 0x17171B)
        let darkText = KitchenLinkV2Palette.RGB(hex: 0xF4F4F1)

        #expect(lightText.contrastRatio(against: lightBase) >= 4.5)
        #expect(darkText.contrastRatio(against: darkBase) >= 4.5)
    }

    @Test
    func kitchenBumpButtonStaysAccessibleInAllStates() {
        let ticketSurface = KitchenLinkV2Palette.RGB(hex: 0x1E1E24)
        let carbonText = KitchenLinkV2Palette.RGB(hex: 0x17171B)
        let restingFill = KitchenLinkV2Palette.RGB(hex: 0xF4F4F1)
        let pressedFill = KitchenLinkV2Palette.RGB(hex: 0xEAEAE5)

        // Text stays readable while resting and pressed.
        #expect(carbonText.contrastRatio(against: restingFill) >= 4.5)
        #expect(carbonText.contrastRatio(against: pressedFill) >= 4.5)

        // The control itself stands out clearly against the dark ticket.
        #expect(restingFill.contrastRatio(against: ticketSurface) >= 3.0)
        #expect(pressedFill.contrastRatio(against: ticketSurface) >= 3.0)
    }

    @Test
    func urgencySymbolsKeepThreeToOneOnTheirSurfaces() {
        let lightSurface = KitchenLinkV2Palette.RGB(hex: 0xF4F4F1)
        let lightSymbols = [0x2E8F5A, 0x656573, 0x9E6705, 0xB3261E]
            .map { KitchenLinkV2Palette.RGB(hex: $0) }

        for symbol in lightSymbols {
            #expect(symbol.contrastRatio(against: lightSurface) >= 3.0)
        }

        let darkSurfaces = [0x121215, 0x0D0D10, 0x1E1E24]
            .map { KitchenLinkV2Palette.RGB(hex: $0) }
        let darkSymbols = [0x3FA96D, 0x888896, 0xD79A2A, 0xEF6E64]
            .map { KitchenLinkV2Palette.RGB(hex: $0) }

        for surface in darkSurfaces {
            for symbol in darkSymbols {
                #expect(symbol.contrastRatio(against: surface) >= 3.0)
            }
        }
    }
}
