import ScrollSwitchCore
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            DeskSettingsView()
                .tabItem { Label("Desk", systemImage: "display.2") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 470)
        .onAppear { activateApp() }
    }
}

private struct GeneralSettingsView: View {
    @EnvironmentObject private var controller: Controller
    @State private var openAtLogin = LaunchAtLogin.isEnabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section {
                Picker("Count as docked when", selection: $controller.settings.rule) {
                    ForEach(TriggerRule.allCases) { rule in
                        Text(rule.label + (rule == .anyDeskDisplay ? " (recommended)" : "")).tag(rule)
                    }
                }
                if let hint = ruleHint {
                    Text(hint).font(.caption).foregroundStyle(.orange)
                }
                Picker("If the lid is open while docked", selection: $controller.settings.lidOpenMeansUndocked) {
                    Text("Treat as docked").tag(false)
                    Text("Treat as undocked (keep trackpad natural)").tag(true)
                }
            }

            Section("Natural scrolling") {
                Picker("When docked", selection: $controller.settings.naturalWhenDocked) {
                    Text("OFF").tag(false)
                    Text("ON").tag(true)
                }
                .pickerStyle(.segmented)
                Picker("When undocked", selection: $controller.settings.naturalWhenUndocked) {
                    Text("ON").tag(true)
                    Text("OFF").tag(false)
                }
                .pickerStyle(.segmented)
            }

            Section {
                Toggle("Show a notification when it switches", isOn: Binding(
                    get: { controller.settings.notificationsEnabled },
                    set: { controller.setNotifications($0) }
                ))
                Toggle("Open at login", isOn: $openAtLogin)
                    .disabled(!LaunchAtLogin.isInstalledCopy)
                    .onChange(of: openAtLogin) { on in
                        do {
                            try LaunchAtLogin.set(on)
                            loginError = nil
                        } catch {
                            loginError = error.localizedDescription
                            openAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
                if !LaunchAtLogin.isInstalledCopy {
                    Text("Install ScrollSwitch in /Applications to open it at login.")
                        .font(.caption).foregroundStyle(.secondary)
                } else if LaunchAtLogin.needsApproval {
                    Text("Approve ScrollSwitch in System Settings › General › Login Items.")
                        .font(.caption).foregroundStyle(.orange)
                }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { openAtLogin = LaunchAtLogin.isEnabled }
    }

    private var ruleHint: String? {
        let s = controller.settings
        if s.rule.needsDeskDisplays && s.rule != .deskOrUSB && s.desk.displays.isEmpty {
            return "No desk monitors saved yet. Use “Save current setup as my desk” while docked."
        }
        if s.rule == .usbDevice && s.desk.usbDevices.isEmpty {
            return "No USB device saved yet. Pick one on the Desk tab."
        }
        if s.rule == .deskOrUSB && s.desk.isEmpty {
            return "Nothing saved yet. Save your desk monitors or pick a USB device on the Desk tab."
        }
        return nil
    }
}

private struct DeskSettingsView: View {
    @EnvironmentObject private var controller: Controller

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $controller.settings.desk.name)
            }

            Section {
                if controller.settings.desk.displays.isEmpty {
                    Text("No monitors saved.").foregroundStyle(.secondary)
                }
                ForEach(controller.settings.desk.displays, id: \.self) { display in
                    HStack {
                        Image(systemName: "display")
                        VStack(alignment: .leading) {
                            Text(display.name)
                            Text("vendor \(display.vendor) · model \(display.model)\(display.serial == 0 ? "" : " · serial \(display.serial)")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if controller.snapshot.externals.contains(where: display.matches) {
                            Text("connected").font(.caption).foregroundStyle(.green)
                        }
                        Button(role: .destructive) {
                            controller.settings.desk.displays.removeAll { $0 == display }
                        } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                            .help("Remove")
                    }
                }
                Button("Save current external displays as my desk") { controller.saveCurrentDesk() }
                    .disabled(controller.externalCount == 0)
            } header: {
                Text("Desk monitors")
            }

            Section {
                if controller.settings.desk.usbDevices.isEmpty {
                    Text("No USB devices saved.").foregroundStyle(.secondary)
                }
                ForEach(controller.settings.desk.usbDevices, id: \.self) { device in
                    HStack {
                        Image(systemName: "cable.connector")
                        Text(device.name)
                        Text(device.hexDescription).font(.caption.monospaced()).foregroundStyle(.secondary)
                        Spacer()
                        if controller.usbPresent.contains(device) {
                            Text("connected").font(.caption).foregroundStyle(.green)
                        }
                        Button(role: .destructive) {
                            controller.setUSBDevice(device, inDesk: false)
                        } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                            .help("Remove")
                    }
                }
                Menu("Add a connected USB device") {
                    ForEach(addableUSB, id: \.self) { device in
                        Button("\(device.name)  (\(device.hexDescription))") {
                            controller.setUSBDevice(device, inDesk: true)
                        }
                    }
                }
                .disabled(addableUSB.isEmpty)
            } header: {
                Text("Desk USB devices (mouse or KVM hub)")
            } footer: {
                Text("Used by the “USB device” rules. Pick something that is only plugged in at your desk.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { controller.refreshNow() }
    }

    private var addableUSB: [USBDeviceID] {
        controller.usbPresent
            .filter { !controller.settings.desk.usbDevices.contains($0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

private struct AboutView: View {
    @EnvironmentObject private var controller: Controller

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: controller.isNatural ? "hand.point.up.left.fill" : "computermouse.fill")
                .font(.system(size: 40))
            Text("ScrollSwitch").font(.title2.bold())
            Text("Version \(version)").foregroundStyle(.secondary)
            Text("Natural scrolling OFF when docked, ON when undocked.")
            Divider().padding(.vertical, 6)
            Grid(alignment: .leading, verticalSpacing: 6) {
                GridRow { Text("Toggle method").foregroundStyle(.secondary); Text(controller.togglerMethod) }
                GridRow { Text("Switches this week").foregroundStyle(.secondary); Text("\(controller.stats.countThisWeek())") }
                GridRow { Text("Live logs").foregroundStyle(.secondary)
                    Text("log stream --predicate 'subsystem == \"\(EventLog.subsystem)\"'")
                        .font(.caption.monospaced()).textSelection(.enabled) }
            }
            Spacer()
        }
        .padding(24)
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}
