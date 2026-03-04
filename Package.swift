// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "supermoji",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "SupermojiKit",
            path: "Sources/SupermojiKit"
        ),
        .executableTarget(
            name: "supermoji",
            dependencies: [
                "SupermojiKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/Supermoji"
        ),
        .executableTarget(
            name: "SupermojiApp",
            dependencies: ["SupermojiKit"],
            path: "Sources/SupermojiApp"
        ),
        .testTarget(
            name: "SupermojiTests",
            dependencies: ["SupermojiKit"],
            path: "Tests/SupermojiTests"
        ),
    ]
)
