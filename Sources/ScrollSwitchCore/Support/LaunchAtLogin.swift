import Foundation
import ServiceManagement

/// Open at login through SMAppService (macOS 13+). Registers the copy that is running, so
/// only call `set(true)` from the installed app in /Applications.
public enum LaunchAtLogin {
    public static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    public static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    public static func set(_ on: Bool) throws {
        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }

    /// True when running from /Applications (or ~/Applications) rather than a build folder.
    public static var isInstalledCopy: Bool {
        let path = Bundle.main.bundlePath
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasSuffix(".app") && (path.hasPrefix("/Applications/") || path.hasPrefix(home + "/Applications/"))
    }
}
