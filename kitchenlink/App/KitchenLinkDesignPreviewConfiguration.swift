import Foundation

enum KitchenLinkDesignVariant: Equatable {
    case v2
    case legacy
}

enum KitchenLinkDesignPreviewConfiguration {
    static let v2LaunchArgument = "--kitchenlink-design-v2"
    static let legacyLaunchArgument = "--kitchenlink-design-legacy"

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
