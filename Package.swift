// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BetterHUD",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "BetterHUD",
            path: "Sources/BetterHUD"
        )
    ]
)
