import AppKit
import ScrollSwitchCore
import SwiftUI

/// The menu bar menu. Spec section 9.2.
struct MenuView: View {
    @ObservedObject var coordinator: ScrollSwitchCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        statusItems
        Divider()
        detectedItems
        Divider()
        directionItems
        Divider()
        toolItems
    }

    @ViewBuilder
    private var statusItems: some View {
        Text(coordinator.stateLine)
        Text(coordinator.directionLine)
        if let note = coordinator.statusNote {
            Text(note)
        }
    }

    @ViewBuilder
    private var detectedItems: some View {
        Text("Detected")
        if coordinator.externalDisplays.isEmpty {
            Text("   No external displays")
        } else {
            ForEach(coordinator.externalDisplays) { display in
                Text("   " + coordinator.detectedLabel(display))
            }
        }
        if coordinator.externalMice.isEmpty {
            Text("   No external pointers")
        } else {
            ForEach(coordinator.externalMice) { mouse in
                Text("   " + coordinator.detectedLabel(mouse))
            }
        }
        Text("   " + coordinator.lidLine)
        Text("   " + coordinator.ruleLine)
    }

    @ViewBuilder
    private var directionItems: some View {
        Button("Force Natural") { coordinator.force(.natural) }
            .disabled(!coordinator.isSupported)
        Button("Force Traditional") { coordinator.force(.traditional) }
            .disabled(!coordinator.isSupported)
        if coordinator.forcedDirection != nil {
            Button("Follow Dock State Again") { coordinator.resumeAutomatic() }
        }
        Button(coordinator.settings.automationEnabled ? "Pause Automation" : "Resume Automation") {
            coordinator.setAutomationEnabled(!coordinator.settings.automationEnabled)
        }
    }

    @ViewBuilder
    private var toolItems: some View {
        Button("Learn My Dock (use what is connected now)") { coordinator.learnMyDock() }
        Button("Re-check Now") { coordinator.reevaluate(trigger: "Menu re-check") }
        Divider()
        Button("Preferences...") { show(WindowID.preferences) }
            .keyboardShortcut(",", modifiers: .command)
        Button("Show Log...") { show(WindowID.log) }
        Divider()
        Button("Quit ScrollSwitch") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }

    /// A menu bar app is an accessory, so a freshly opened window needs an explicit
    /// activation or it appears behind whatever you were using.
    private func show(_ id: String) {
        openWindow(id: id)
        NSApp.activate(ignoringOtherApps: true)
    }
}
