import Foundation

public enum DockState: String, Codable, Sendable {
    case docked, undocked

    public var label: String { self == .docked ? "Docked" : "Undocked" }
}

/// What counts as "docked".
public enum TriggerRule: String, Codable, CaseIterable, Identifiable, Sendable {
    case anyExternal
    case anyDeskDisplay
    case allDeskDisplays
    case usbDevice
    case deskOrUSB

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .anyExternal: return "Any external display"
        case .anyDeskDisplay: return "My desk is connected"
        case .allDeskDisplays: return "My desk is fully connected"
        case .usbDevice: return "My USB device is connected"
        case .deskOrUSB: return "Desk display or USB device"
        }
    }

    public var needsDeskDisplays: Bool {
        self == .anyDeskDisplay || self == .allDeskDisplays || self == .deskOrUSB
    }

    public var needsUSB: Bool { self == .usbDevice || self == .deskOrUSB }
}

/// Whether automatic switching is paused, and until when.
public enum PauseState: Codable, Equatable, Sendable {
    case none
    case until(Date)
    /// Paused until the dock state differs from the one it was paused in.
    case untilNextChange(from: DockState)
    case indefinitely

    /// Pause state after letting any timed pause expire.
    public func resolved(now: Date) -> PauseState {
        if case .until(let end) = self, end <= now { return .none }
        return self
    }

    public func isActive(now: Date) -> Bool { resolved(now: now) != .none }
}

/// Every user choice. Stored as one JSON blob in the app's UserDefaults.
public struct SwitchSettings: Codable, Equatable, Sendable {
    public var rule: TriggerRule = .anyExternal
    public var desk = DeskProfile()
    public var lidOpenMeansUndocked = false
    public var naturalWhenDocked = false
    public var naturalWhenUndocked = true
    public var notificationsEnabled = false
    public var pause: PauseState = .none

    public init() {}

    public func natural(for state: DockState) -> Bool {
        state == .docked ? naturalWhenDocked : naturalWhenUndocked
    }

    // Decode field by field so a settings blob from an older build never resets everything.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SwitchSettings()
        rule = (try? c.decode(TriggerRule.self, forKey: .rule)) ?? d.rule
        desk = (try? c.decode(DeskProfile.self, forKey: .desk)) ?? d.desk
        lidOpenMeansUndocked = (try? c.decode(Bool.self, forKey: .lidOpenMeansUndocked)) ?? d.lidOpenMeansUndocked
        naturalWhenDocked = (try? c.decode(Bool.self, forKey: .naturalWhenDocked)) ?? d.naturalWhenDocked
        naturalWhenUndocked = (try? c.decode(Bool.self, forKey: .naturalWhenUndocked)) ?? d.naturalWhenUndocked
        notificationsEnabled = (try? c.decode(Bool.self, forKey: .notificationsEnabled)) ?? d.notificationsEnabled
        pause = (try? c.decode(PauseState.self, forKey: .pause)) ?? d.pause
    }
}
