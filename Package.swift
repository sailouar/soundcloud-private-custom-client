// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SoundCloudCore",
    platforms: [
        .iOS(.v17),
        // Host builds (`swift test` on macOS/Windows/Linux) need a modern
        // deployment target for concurrency (Task) and CryptoKit (SHA256).
        .macOS(.v14)
    ],
    dependencies: [
        // Provides the CryptoKit module on Windows/Linux; on Apple platforms
        // it forwards to the system CryptoKit, so the iOS build is unchanged.
        .package(url: "https://github.com/apple/swift-crypto", from: "1.5.0")
    ],
    products: [
        .library(name: "SoundCloudCore", targets: ["SoundCloudCore"])
    ],
    targets: [
        .target(
            name: "SoundCloudCore",
            dependencies: [
                .product(name: "CryptoKit", package: "swift-crypto")
            ],
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
