// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HermesCompanion",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "HermesCompanion", targets: ["HermesCompanion"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "HermesCompanion",
            dependencies: [],
            path: "Sources/HermesCompanion"
        ),
        .testTarget(
            name: "HermesCompanionTests",
            dependencies: ["HermesCompanion"],
            path: "Tests/HermesCompanionTests"
        )
    ]
)
