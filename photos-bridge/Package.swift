// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "photos-bridge",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        // PhotoKit access and the JSON event types. Kept separate from the
        // executable so it can be unit tested.
        .target(name: "PhotosBridgeCore"),
        .executableTarget(
            name: "photos-bridge",
            dependencies: [
                "PhotosBridgeCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "PhotosBridgeCoreTests",
            dependencies: ["PhotosBridgeCore"]
        ),
    ]
)
