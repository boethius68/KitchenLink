import Testing
@testable import kitchenlink

struct KitchenLinkDesignPreviewConfigurationTests {
    @Test func v2IsTheDefaultPreview() {
        #expect(KitchenLinkDesignPreviewConfiguration.initialVariant(arguments: []) == .v2)
    }

    @Test func legacyLaunchArgumentOverridesThePreview() {
        let arguments = ["KitchenLink", KitchenLinkDesignPreviewConfiguration.legacyLaunchArgument]

        #expect(KitchenLinkDesignPreviewConfiguration.initialVariant(arguments: arguments) == .legacy)
    }

    @Test func explicitV2KeepsThePreviewEnabled() {
        let arguments = [
            "KitchenLink",
            KitchenLinkDesignPreviewConfiguration.legacyLaunchArgument,
            KitchenLinkDesignPreviewConfiguration.v2LaunchArgument
        ]

        #expect(KitchenLinkDesignPreviewConfiguration.initialVariant(arguments: arguments) == .v2)
    }
}
