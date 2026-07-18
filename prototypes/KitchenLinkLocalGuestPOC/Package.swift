// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitchenLinkLocalGuestPOC",
    platforms: [.macOS(.v14)],
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
            dependencies: ["KitchenLinkEventLog"]
        ),
        .executableTarget(
            name: "KitchenLinkLocalGuestServer",
            dependencies: ["KitchenLinkLocalGuestCore"],
            resources: [.process("Public")]
        ),
        .testTarget(
            name: "KitchenLinkLocalGuestCoreTests",
            dependencies: ["KitchenLinkLocalGuestCore", "KitchenLinkEventLog"]
        )
    ]
)
