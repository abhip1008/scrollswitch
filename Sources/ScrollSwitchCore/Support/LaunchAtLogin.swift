import Foundation
import ServiceManagement

/// Launch at login via SMAppService (FR-9, macOS 13+).
///
/// SMAppService only works from a real signed .app bundle, so running the raw SwiftPM
/// binary reports notFound. That is why `make app` exists.
public enum LaunchAtLogin {
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public static var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            return "Enabled"
        case .notRegistered:
            return "Not registered"
        case .requiresApproval:
            return "Waiting for approval in System Settings > General > Login Items"
        case .notFound:
            return "Unavailable (run ScrollSwitch from an installed .app bundle)"
        @unknown default:
            return "Unknown"
        }
    }

    /// Returns the error rather than throwing, because the caller is a SwiftUI toggle
    /// that needs to roll itself back on failure.
    public static func set(_ enabled: Bool) -> Error? {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return error
        }
    }
}
