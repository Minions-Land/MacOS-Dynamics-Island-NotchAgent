// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "NotchAgent",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "NotchAgent",
            path: "Sources/NotchAgent",
            exclude: ["Info.plist"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
