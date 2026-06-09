// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CodexGauge",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "CodexGauge",
            path: "Sources/CodexGauge"
        )
    ]
)
