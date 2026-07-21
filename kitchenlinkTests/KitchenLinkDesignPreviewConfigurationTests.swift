import Testing
@testable import kitchenlink

struct KitchenLinkDesignPreviewConfigurationTests {
    @Test func appearanceIsUnforcedByDefault() {
        #expect(KitchenLinkDesignPreviewConfiguration.forcedAppearance(arguments: []) == nil)
    }

    @Test func lastAppearanceArgumentWins() {
        let arguments = [
            "KitchenLink",
            KitchenLinkDesignPreviewConfiguration.darkAppearanceLaunchArgument,
            KitchenLinkDesignPreviewConfiguration.lightAppearanceLaunchArgument,
        ]
        #expect(KitchenLinkDesignPreviewConfiguration.forcedAppearance(arguments: arguments) == .light)
    }

    @Test func demoSeedArgumentsRemainIndependent() {
        #expect(KitchenLinkDesignPreviewConfiguration.shouldSeedDemoService(arguments: [
            KitchenLinkDesignPreviewConfiguration.demoServiceLaunchArgument,
        ]))
        #expect(!KitchenLinkDesignPreviewConfiguration.shouldSeedDemoInventory(arguments: [
            KitchenLinkDesignPreviewConfiguration.demoServiceLaunchArgument,
        ]))
    }
}
