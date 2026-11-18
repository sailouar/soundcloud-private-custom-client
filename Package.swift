// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SoundCloudCore",
    platforms: [
        .iOS(.v17),
        // Host builds (`swift test` on a macOS runner) need a modern macOS
        // target for concurrency (Task) and CryptoKit (SHA256).
        .macOS(.v14)
    ],
    products: [
        .library(name: "SoundCloudCore", targets: ["SoundCloudCore"])
    ],
    targets: [
        .target(
            name: "SoundCloudCore",
            path: "Sources/SoundCloudCore"
        ),
        .testTarget(
            name: "SoundCloudCoreTests",
            dependencies: ["SoundCloudCore"],
            path: "ios/SoundCloudPersonalTests",
            exclude: [
                "CapabilityAdapterIntegrationTests.swift",
                "StorageMigrationSmokeTests.swift"
            ],
            swiftSettings: [
                .define("SOUNDCLOUD_STORAGE_SWIFTDATA")
            ]
        )
    ]
)
