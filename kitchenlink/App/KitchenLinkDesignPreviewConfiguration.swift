import Foundation

enum KitchenLinkDesignVariant: Equatable {
    case v2
    case legacy
}

enum KitchenLinkForcedAppearance: Equatable {
    case light
    case dark
}

enum KitchenLinkDesignPreviewConfiguration {
    static let v2LaunchArgument = "--kitchenlink-design-v2"
    static let legacyLaunchArgument = "--kitchenlink-design-legacy"

    /// Sandbox-only: seeds the demo service scenario when Heute or Küche appear.
    static let demoServiceLaunchArgument = "--kitchenlink-demo-service"

    /// Sandbox-only: forces an appearance for reproducible visual checks.
    static let lightAppearanceLaunchArgument = "--kitchenlink-appearance-light"
    static let darkAppearanceLaunchArgument = "--kitchenlink-appearance-dark"

    static func shouldSeedDemoService(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        arguments.contains(demoServiceLaunchArgument)
    }

    static func forcedAppearance(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> KitchenLinkForcedAppearance? {
        for argument in arguments.reversed() {
            switch argument {
            case darkAppearanceLaunchArgument:
                return .dark
            case lightAppearanceLaunchArgument:
                return .light
            default:
                continue
            }
        }

        return nil
    }

    static func initialVariant(arguments: [String] = ProcessInfo.processInfo.arguments) -> KitchenLinkDesignVariant {
        for argument in arguments.reversed() {
            switch argument {
            case v2LaunchArgument:
                return .v2
            case legacyLaunchArgument:
                return .legacy
            default:
                continue
            }
        }

        return .v2
    }
}
