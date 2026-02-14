// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-hoot",
    products: [
        .library(
            name: "Hoot",
            targets: ["Hoot"]
        ),
    ],
    targets: [
        .target(
            name: "Hoot"
        ),
        .testTarget(
            name: "HootTests",
            dependencies: ["Hoot"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
