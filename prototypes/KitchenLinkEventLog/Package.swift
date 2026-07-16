// swift-tools-version: 6.0
//
//  KitchenLinkEventLog
//
//  KL-OFFLINE-003 — Authoritative local event log + outbox reference prototype.
//
//  This is a standalone Swift Package. It uses the system SQLite3 library
//  (shipped with every Apple SDK) via the C `SQLite3` module. It deliberately
//  introduces NO dependency on the KitchenLink iOS app; the app integration
//  seam is documented in `docs/architecture/offline/EVENT_LOG_V2.md`.
//
//  Primary sources for every SQLite/Swift claim are cited inline and in
//  EVENT_LOG_V2.md.
import PackageDescription

let package = Package(
    name: "KitchenLinkEventLog",
    platforms: [
        // The package targets the system SQLite3 modulemap, which is available
        // across iOS / iPadOS / macOS. We declare platforms for clarity; the
        // logic is platform-neutral and is unit-tested on the host.
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "KitchenLinkEventLog", targets: ["KitchenLinkEventLog"])
    ],
    targets: [
        .target(
            name: "KitchenLinkEventLog",
            path: "Sources/KitchenLinkEventLog"
        ),
        .testTarget(
            name: "KitchenLinkEventLogTests",
            dependencies: ["KitchenLinkEventLog"],
            path: "Tests/KitchenLinkEventLogTests"
        )
    ]
)
