import ScrollSwitchCore
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var controller: Controller
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(statusLine)
        Text("Natural scrolling: \(controller.isNatural ? "ON" : "OFF")")
        if let pauseLine {
            Text(pauseLine)
        }
        if let warning = controller.togglerWarning {
            Text("⚠︎ Can't control scrolling live on this macOS version")
                .help(warning)
        }
        if controller.applyFailed {
            Text("⚠︎ Last change did not stick. See Recent activity.")
        }

        Divider()

        Toggle("Automatic switching", isOn: Binding(
            get: { !controller.isPaused },
            set: { on in on ? controller.resume() : controller.pauseIndefinitely() }
        ))
        if controller.isPaused {
            Button("Resume automatic switching") { controller.resume() }
        } else {
            Button("Pause for 1 hour") { controller.pause(for: 3600) }
            Button(controller.dockState == .docked ? "Pause until I unplug" : "Pause until I plug in") {
                controller.pauseUntilNextChange()
            }
            Button("Pause indefinitely") { controller.pauseIndefinitely() }
        }

        Divider()

        Button("Turn Natural scrolling \(controller.isNatural ? "OFF" : "ON") now") { controller.flipNow() }

        Divider()

        Button("Save current setup as my desk") { controller.saveCurrentDesk() }
            .disabled(controller.externalCount == 0)
        Button("Recent activity…") { show(WindowID.activity) }
        Button("Settings…") { show(WindowID.settings) }
            .keyboardShortcut(",")

        Divider()

        Button("Quit ScrollSwitch") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var statusLine: String {
        guard let state = controller.dockState else { return "○ Checking displays…" }
        let n = controller.externalCount
        let displays = n == 0 ? "no external displays" : "\(n) external display\(n == 1 ? "" : "s")"
        return "\(state == .docked ? "●" : "○") \(state.label): \(displays)"
    }

    private var pauseLine: String? {
        switch controller.settings.pause.resolved(now: Date()) {
        case .none: return nil
        case .indefinitely: return "⏸ Paused"
        case .untilNextChange(let from): return "⏸ Paused until the next \(from == .docked ? "unplug" : "plug-in")"
        case .until(let end): return "⏸ Paused until \(end.formatted(date: .omitted, time: .shortened))"
        }
    }

    private func show(_ id: String) {
        openWindow(id: id)
        activateApp()
    }
}
