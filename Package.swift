// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SA2SeedKey",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "SA2SeedKey", targets: ["SA2SeedKey"]),
    ],
    targets: [
        .target(name: "SA2SeedKey"),
        .testTarget(name: "SA2SeedKeyTests", dependencies: ["SA2SeedKey"]),
    ]
)
