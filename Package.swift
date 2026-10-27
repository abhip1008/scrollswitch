// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ScrollSwitch",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ScrollSwitch", targets: ["ScrollSwitch"]),
        .executable(name: "scrollswitch-cli", targets: ["scrollswitch-cli"]),
        .library(name: "ScrollSwitchCore", targets: ["ScrollSwitchCore"]),
    ],
    targets: [
        // All logic: detection, decision, toggling. No UI.
        .target(name: "ScrollSwitchCore"),
        // The menu bar app (assembled into ScrollSwitch.app by the Makefile).
        .executableTarget(name: "ScrollSwitch", dependencies: ["ScrollSwitchCore"]),
        // Phase 1 command-line engine, also handy for diagnostics.
        .executableTarget(name: "scrollswitch-cli", dependencies: ["ScrollSwitchCore"]),
        .testTarget(name: "ScrollSwitchCoreTests", dependencies: ["ScrollSwitchCore"]),
    ]
)
