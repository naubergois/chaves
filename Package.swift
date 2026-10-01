// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Chaves",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Chaves",
            path: "Sources/Chaves"
        ),
        .testTarget(
            name: "ChavesTests",
            dependencies: ["Chaves"],
            path: "Tests/ChavesTests"
        ),
    ]
)
