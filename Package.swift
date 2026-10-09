// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ScrollSwitch",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ScrollSwitch", targets: ["ScrollSwitchApp"]),
        .executable(name: "scrollswitch-spike", targets: ["APISpike"]),
        .library(name: "ScrollSwitchCore", targets: ["ScrollSwitchCore"]),
    ],
    targets: [
        .target(
            name: "ScrollSwitchCore",
            path: "Sources/ScrollSwitchCore"
        ),
        .executableTarget(
            name: "ScrollSwitchApp",
            dependencies: ["ScrollSwitchCore"],
            path: "Sources/ScrollSwitchApp"
        ),
        .executableTarget(
            name: "APISpike",
            dependencies: ["ScrollSwitchCore"],
            path: "Sources/APISpike"
        ),
        .testTarget(
            name: "ScrollSwitchTests",
            dependencies: ["ScrollSwitchCore"],
            path: "Tests/ScrollSwitchTests"
        ),
    ]
)
