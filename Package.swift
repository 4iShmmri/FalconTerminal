// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FalconTerminal",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "FalconTerminal", targets: ["FalconTerminal"])
    ],
    targets: [
        .executableTarget(
            name: "FalconTerminal",
            path: "Sources/FalconTerminal",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "FalconTerminalTests",
            dependencies: ["FalconTerminal"],
            path: "Tests/FalconTerminalTests"
        )
    ]
)
