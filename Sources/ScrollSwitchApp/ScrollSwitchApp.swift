import AppKit
import ScrollSwitchCore
import SwiftUI

enum WindowID {
    static let preferences = "scrollswitch.preferences"
    static let log = "scrollswitch.log"
}

/// Holds the one coordinator so both the Scene and the app delegate can reach it.
final class AppEnvironment {
    static let shared = AppEnvironment()
    let coordinator = ScrollSwitchCoordinator()
    private init() {}
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Belt and braces alongside LSUIElement: menu bar only, no Dock icon.
        NSApp.setActivationPolicy(.accessory)
        AppEnvironment.shared.coordinator.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppEnvironment.shared.coordinator.stop()
    }

    /// Closing Preferences or the log should not quit a menu bar app.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct ScrollSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var coordinator = AppEnvironment.shared.coordinator

    var body: some Scene {
        MenuBarExtra {
            MenuView(coordinator: coordinator)
        } label: {
            Image(systemName: coordinator.menuBarSymbol)
                .accessibilityLabel(coordinator.stateLine)
        }
        .menuBarExtraStyle(.menu)

        Window("ScrollSwitch Preferences", id: WindowID.preferences) {
            PreferencesView(coordinator: coordinator)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 480, height: 460)

        Window("ScrollSwitch Log", id: WindowID.log) {
            LogView(log: coordinator.log)
        }
        .defaultSize(width: 640, height: 440)
    }
}
