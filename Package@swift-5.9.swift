// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Botsi",
    platforms: [
        .iOS(.v13),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "Botsi",
            targets: ["Botsi"]
        )
    ],
    targets: [
        .target(
            name: "Botsi",
            path: "Sources"
        ),
        .testTarget(
            name: "BotsiSDK-iOSTests",
            dependencies: ["Botsi"],
            path: "Tests"
        )
    ]
)
