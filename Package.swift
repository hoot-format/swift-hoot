// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-hoot",
    products: [
        .library(
            name: "Hoot",
            targets: ["Hoot"]
        ),
        .executable(
            name: "hoot",
            targets: ["HootCLI"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser.git",
            from: "1.5.0"
        ),
    ],
    targets: [
        .target(
            name: "Hoot"
        ),
        .executableTarget(
            name: "HootCLI",
            dependencies: [
                "Hoot",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "HootTests",
            dependencies: ["Hoot"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
