// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "PeekabooDesktop",
    products: [
        .library(
            name: "PeekabooDesktop",
            targets: ["PeekabooDesktop"]),
    ],
    targets: [
        .target(
            name: "PeekabooDesktop"),
        .testTarget(
            name: "PeekabooDesktopTests",
            dependencies: ["PeekabooDesktop"]),
    ],
    swiftLanguageModes: [.v6])

