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
    dependencies: [
        .package(path: "../../../Core/PeekabooDesktop"),
    ],
    targets: [
        .target(
            name: "PeekabooWin11Interop",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedLibrary("Ole32", .when(platforms: [.windows])),
                .linkedLibrary("OleAut32", .when(platforms: [.windows])),
                .linkedLibrary("Uuid", .when(platforms: [.windows])),
                .linkedLibrary("Uiautomationcore", .when(platforms: [.windows])),
            ]),
        .target(
            name: "PeekabooWin11Core",
            dependencies: [
                "PeekabooWin11Interop",
                .product(name: "PeekabooDesktop", package: "PeekabooDesktop"),
            ]),
        .executableTarget(
            name: "PeekabooWin11CLI",
            dependencies: ["PeekabooWin11Core"],
            path: "Sources/PeekabooWin11CLI"),
        .testTarget(
            name: "PeekabooWin11CoreTests",
            dependencies: ["PeekabooWin11Core"]),
    ],
    swiftLanguageModes: [.v6])
