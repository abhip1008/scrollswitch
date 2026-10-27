import Foundation

/// Decides docked vs undocked. Pure: no system calls, so every rule can be unit tested.
public enum DockStateEvaluator {
    public static func evaluate(snapshot: DisplaySnapshot,
                                usbPresent: Set<USBDeviceID>,
                                lidOpen: Bool,
                                settings: SwitchSettings) -> DockState {
        let deskDisplays = settings.desk.displays
        let matched = deskDisplays.filter { desk in snapshot.externals.contains { desk.matches($0) } }
        let usbMatch = !usbPresent.isDisjoint(with: Set(settings.desk.usbDevices))

        let docked: Bool
        switch settings.rule {
        case .anyExternal: docked = !snapshot.externals.isEmpty
        case .anyDeskDisplay: docked = !matched.isEmpty
        case .allDeskDisplays: docked = !deskDisplays.isEmpty && matched.count == deskDisplays.count
        case .usbDevice: docked = usbMatch
        case .deskOrUSB: docked = !matched.isEmpty || usbMatch
        }

        if docked && lidOpen && settings.lidOpenMeansUndocked { return .undocked }
        return docked ? .docked : .undocked
    }
}
