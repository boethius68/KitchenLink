import Foundation

enum KitchenLinkForcedAppearance: Equatable {
    case light
    case dark
}

enum KitchenLinkDesignPreviewConfiguration {
    /// Sandbox-only: seeds the demo service scenario when Heute or Küche appear.
    static let demoServiceLaunchArgument = "--kitchenlink-demo-service"

    /// Sandbox-only: seeds the demo inventory fixture when the Bestand surface
    /// appears. Additive alongside `demoServiceLaunchArgument` so the two
    /// demo paths stay independently controllable from launch arguments.
    static let demoInventoryLaunchArgument = "--kitchenlink-demo-inventory"

    /// Sandbox-only: shows a demo table set in the Tische surface instead of
    /// loading from the cloud. Same purpose as the two arguments above — the
    /// layout, the QR sheet and the empty/inactive states stay reviewable
    /// without an operator session or an applied migration.
    static let demoTablesLaunchArgument = "--kitchenlink-demo-tables"

    /// Sandbox-only: forces an appearance for reproducible visual checks.
    static let lightAppearanceLaunchArgument = "--kitchenlink-appearance-light"
    static let darkAppearanceLaunchArgument = "--kitchenlink-appearance-dark"

    static func shouldSeedDemoService(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        arguments.contains(demoServiceLaunchArgument)
    }

    static func shouldSeedDemoInventory(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        arguments.contains(demoInventoryLaunchArgument)
    }

    static func shouldSeedDemoTables(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        arguments.contains(demoTablesLaunchArgument)
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

}
