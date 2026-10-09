import AppKit
import ScrollSwitchCore
import SwiftUI

/// One window, three tabs. Spec section 9.3.
struct PreferencesView: View {
    @ObservedObject var coordinator: ScrollSwitchCoordinator

    var body: some View {
        TabView {
            GeneralTab(coordinator: coordinator)
                .tabItem { Label("General", systemImage: "gearshape") }
            DockingTab(coordinator: coordinator)
                .tabItem { Label("Docking", systemImage: "display.2") }
            StatusTab(coordinator: coordinator)
                .tabItem { Label("Status", systemImage: "info.circle") }
        }
        .padding(14)
        .frame(width: 480, height: 460)
    }
}

private struct GeneralTab: View {
    @ObservedObject var coordinator: ScrollSwitchCoordinator

    var body: some View {
        Form {
            Section {
                Toggle("Automation enabled", isOn: coordinator.automationBinding)
                Toggle("Launch at login", isOn: coordinator.binding(\.launchAtLogin))
                Toggle("Notify when the direction changes", isOn: coordinator.binding(\.notifyOnChange))
            }

            Section("Direction for each state") {
                Picker("When docked", selection: coordinator.binding(\.dockedDirection)) {
                    directionOptions
                }
                Picker("When undocked", selection: coordinator.binding(\.undockedDirection)) {
                    directionOptions
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var directionOptions: some View {
        ForEach(ScrollDirection.allCases) { direction in
            Text(direction.displayName).tag(direction)
        }
    }
}

private struct DockingTab: View {
    @ObservedObject var coordinator: ScrollSwitchCoordinator

    var body: some View {
        Form {
            Section("Docking rule") {
                Picker("Docked when", selection: coordinator.binding(\.rule)) {
                    ForEach(DockRule.allCases) { rule in
                        Text(rule.displayName).tag(rule)
                    }
                }
                Text(coordinator.settings.rule.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Also require the lid to be closed", isOn: coordinator.binding(\.requireLidClosed))
            }

            Section("Dock markers") {
                if hasNoMarkers {
                    Text("Nothing learned yet. Plug into your dock, then press Learn My Dock.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(coordinator.settings.markerDisplays) { marker in
                        markerRow(
                            label: coordinator.settings.label(for: marker),
                            symbol: "display"
                        ) {
                            coordinator.removeMarker(display: marker)
                        }
                    }
                    ForEach(coordinator.settings.markerMice) { marker in
                        markerRow(
                            label: coordinator.settings.label(for: marker),
                            symbol: "computermouse"
                        ) {
                            coordinator.removeMarker(mouse: marker)
                        }
                    }
                }

                HStack {
                    Button("Learn My Dock") { coordinator.learnMyDock() }
                    Button("Forget All") { coordinator.forgetMarkers() }
                        .disabled(hasNoMarkers)
                }
            }

            Section("Debounce") {
                Slider(value: coordinator.binding(\.debounceSeconds), in: 0.5...5.0, step: 0.5)
                Text(debounceCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var hasNoMarkers: Bool {
        coordinator.settings.markerDisplays.isEmpty && coordinator.settings.markerMice.isEmpty
    }

    private var debounceCaption: String {
        let seconds = coordinator.settings.debounceSeconds
        return String(format: "Wait %.1f s for the signals to settle before switching.", seconds)
    }

    private func markerRow(
        label: String,
        symbol: String,
        remove: @escaping () -> Void
    ) -> some View {
        HStack {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
            Text(label)
            Spacer()
            Button("Remove", action: remove)
                .buttonStyle(.borderless)
        }
    }
}

private struct StatusTab: View {
    @ObservedObject var coordinator: ScrollSwitchCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Form {
            Section("Scroll API") {
                LabeledContent("Supported on this macOS", value: coordinator.isSupported ? "Yes" : "No")
                if let reason = coordinator.unsupportedReason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Right now") {
                LabeledContent("State", value: coordinator.dockState?.displayName ?? "Evaluating")
                LabeledContent("Scrolling", value: coordinator.direction.displayName)
                LabeledContent("Rule", value: coordinator.ruleLine)
                LabeledContent("Lid", value: coordinator.lidLine)
                LabeledContent("External displays", value: "\(coordinator.externalDisplays.count)")
                LabeledContent("External pointers", value: "\(coordinator.externalMice.count)")
                LabeledContent("Launch at login", value: coordinator.launchAtLoginStatus)
                if let note = coordinator.statusNote {
                    LabeledContent("Note", value: note)
                }
            }

            Section {
                Button("Re-check Now") { coordinator.reevaluate(trigger: "Preferences re-check") }
                Button("Show Log...") {
                    openWindow(id: WindowID.log)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
        .formStyle(.grouped)
    }
}
