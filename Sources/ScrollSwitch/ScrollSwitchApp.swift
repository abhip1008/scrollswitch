import AppKit
import ScrollSwitchCore
import SwiftUI

/// One controller for the whole app, shared by the scenes and the app delegate.
@MainActor
enum AppModel {
    static let controller = Controller.live()
    static let store = SettingsStore()
    static let firstLaunchKey = "didRegisterLoginItem"
}

@main
struct ScrollSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var controller = AppModel.controller

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(controller)
        } label: {
            Image(nsImage: MenuBarIcon.image(natural: controller.isNatural,
                                             paused: controller.isPaused,
                                             warning: controller.applyFailed || controller.togglerWarning != nil))
                .accessibilityLabel("ScrollSwitch: Natural scrolling \(controller.isNatural ? "on" : "off")")
        }
        .menuBarExtraStyle(.menu)

        Window("ScrollSwitch Settings", id: WindowID.settings) {
            SettingsView()
                .environmentObject(controller)
        }
        .windowResizability(.contentSize)

        Window("Recent Activity", id: WindowID.activity) {
            ActivityLogView()
                .environmentObject(controller)
                .environmentObject(controller.log)
        }
        .defaultSize(width: 560, height: 420)
    }
}

enum WindowID {
    static let settings = "settings"
    static let activity = "activity"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Used by `make uninstall` so no login item is left pointing at a deleted app.
        if CommandLine.arguments.contains("--unregister-login-item") {
            try? LaunchAtLogin.set(false)
            exit(0)
        }
        if let other = otherRunningCopy() {
            NSLog("ScrollSwitch is already running (pid \(other.processIdentifier)); quitting this copy.")
            NSApp.terminate(nil)
            return
        }
        MainActor.assumeIsolated {
            registerLoginItemOnFirstLaunch()
            AppModel.controller.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // The setting stays wherever it is. Nothing to undo.
        MainActor.assumeIsolated { AppModel.controller.stop() }
    }

    private func otherRunningCopy() -> NSRunningApplication? {
        guard let id = Bundle.main.bundleIdentifier else { return nil }
        let me = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication.runningApplications(withBundleIdentifier: id).first { $0.processIdentifier != me }
    }

    /// "Open at login" defaults to ON, but only for the copy installed in /Applications, so
    /// a build-folder copy never becomes the login item.
    @MainActor
    private func registerLoginItemOnFirstLaunch() {
        guard LaunchAtLogin.isInstalledCopy, !AppModel.store.bool(AppModel.firstLaunchKey) else { return }
        do {
            try LaunchAtLogin.set(true)
            AppModel.controller.log.add(.info, "Registered to open at login")
        } catch {
            AppModel.controller.log.add(.warning, "Could not register to open at login: \(error.localizedDescription)")
        }
        AppModel.store.set(true, for: AppModel.firstLaunchKey)
    }
}

/// Bring an LSUIElement app's windows to the front.
@MainActor
func activateApp() {
    if #available(macOS 14.0, *) {
        NSApp.activate()
    } else {
        NSApp.activate(ignoringOtherApps: true)
    }
}
