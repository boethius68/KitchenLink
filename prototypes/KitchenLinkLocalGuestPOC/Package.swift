// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitchenLinkLocalGuestPOC",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "KitchenLinkLocalGuestCore", targets: ["KitchenLinkLocalGuestCore"]),
        .executable(name: "kitchenlink-local-guest", targets: ["KitchenLinkLocalGuestServer"])
    ],
    dependencies: [
        .package(path: "../KitchenLinkEventLog")
    ],
    targets: [
        .target(
            name: "KitchenLinkLocalGuestCore",
            dependencies: ["KitchenLinkEventLog"],
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "KitchenLinkLocalGuestServer",
            dependencies: ["KitchenLinkLocalGuestCore"]
        ),
        .testTarget(
            name: "KitchenLinkLocalGuestCoreTests",
            dependencies: ["KitchenLinkLocalGuestCore", "KitchenLinkEventLog"]
        )
    ]
)
