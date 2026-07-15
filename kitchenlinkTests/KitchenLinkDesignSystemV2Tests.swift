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
}
