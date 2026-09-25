// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BetterHUD",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "BetterHUD",
            path: "Sources/BetterHUD"
        ),
        // Covers the parts that are pure logic. The rest of the app is event
        // taps, CoreAudio, and a private display framework, none of which can
        // be stood up in a test process.
        .testTarget(
            name: "BetterHUDTests",
            dependencies: ["BetterHUD"],
            path: "Tests/BetterHUDTests"
        ),
    ]
)
