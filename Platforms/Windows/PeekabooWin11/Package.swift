// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "PeekabooWin11",
    products: [
        .library(
            name: "PeekabooWin11Core",
            targets: ["PeekabooWin11Core"]),
        .executable(
            name: "peekaboo-win11",
            targets: ["PeekabooWin11CLI"]),
    ],
    targets: [
        .target(
            name: "PeekabooWin11Core"),
        .executableTarget(
            name: "PeekabooWin11CLI",
            dependencies: ["PeekabooWin11Core"],
            path: "Sources/PeekabooWin11CLI"),
        .testTarget(
            name: "PeekabooWin11CoreTests",
            dependencies: ["PeekabooWin11Core"]),
    ],
    swiftLanguageModes: [.v6])
