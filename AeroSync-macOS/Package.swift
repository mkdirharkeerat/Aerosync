// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AeroSync",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "AeroSync",
            targets: ["AeroSync"]
        )
    ],
    targets: [
        .executableTarget(
            name: "AeroSync",
            path: "Sources/AeroSync"
        )
    ]
)
