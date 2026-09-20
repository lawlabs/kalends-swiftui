// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Kalends",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "Kalends", targets: ["Kalends"]),
    ],
    targets: [
        .target(
            name: "Kalends",
            path: "Sources/Kalends",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "KalendsTests",
            dependencies: ["Kalends"],
            path: "Tests/KalendsTests"
        ),
    ]
)
