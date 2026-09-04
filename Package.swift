// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CenterHUD",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CenterHUD",
            path: "Sources/CenterHUD"
        )
    ]
)
