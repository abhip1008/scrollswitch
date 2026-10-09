import Foundation

/// Everything the user can configure. Spec section 8. Stored as JSON in the app own
/// UserDefaults domain, so nothing here leaves the machine.
public struct Settings: Codable, Equatable, Sendable {
    public var automationEnabled: Bool = true
    public var rule: DockRule = .anyExternalDisplay
    public var requireLidClosed: Bool = false
    public var dockedDirection: ScrollDirection = .traditional
    public var undockedDirection: ScrollDirection = .natural
    public var markerDisplays: [DisplayID] = []
    public var markerMice: [MouseID] = []
    public var debounceSeconds: Double = 1.5
    public var notifyOnChange: Bool = false
    public var launchAtLogin: Bool = true

    /// Human readable labels for markers, keyed by DisplayID.id / MouseID.id, so the
    /// Preferences marker list stays readable after the device is unplugged.
    public var markerLabels: [String: String] = [:]

    public init() {}

    public func direction(for state: DockState) -> ScrollDirection {
        state == .docked ? dockedDirection : undockedDirection
    }

    public func label(for display: DisplayID) -> String {
        markerLabels[display.id] ?? "Display \(display.id)"
    }

    public func label(for mouse: MouseID) -> String {
        markerLabels[mouse.id] ?? "Mouse \(mouse.id)"
    }

    /// Hand rolled decoding so an older settings blob missing a key still loads with
    /// that key at its default instead of failing the whole decode.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var d = Settings()
        d.automationEnabled = try c.decodeIfPresent(Bool.self, forKey: .automationEnabled) ?? d.automationEnabled
        d.rule = try c.decodeIfPresent(DockRule.self, forKey: .rule) ?? d.rule
        d.requireLidClosed = try c.decodeIfPresent(Bool.self, forKey: .requireLidClosed) ?? d.requireLidClosed
        d.dockedDirection = try c.decodeIfPresent(ScrollDirection.self, forKey: .dockedDirection) ?? d.dockedDirection
        d.undockedDirection = try c.decodeIfPresent(ScrollDirection.self, forKey: .undockedDirection) ?? d.undockedDirection
        d.markerDisplays = try c.decodeIfPresent([DisplayID].self, forKey: .markerDisplays) ?? d.markerDisplays
        d.markerMice = try c.decodeIfPresent([MouseID].self, forKey: .markerMice) ?? d.markerMice
        d.debounceSeconds = try c.decodeIfPresent(Double.self, forKey: .debounceSeconds) ?? d.debounceSeconds
        d.notifyOnChange = try c.decodeIfPresent(Bool.self, forKey: .notifyOnChange) ?? d.notifyOnChange
        d.launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? d.launchAtLogin
        d.markerLabels = try c.decodeIfPresent([String: String].self, forKey: .markerLabels) ?? d.markerLabels
        self = d
    }
}

/// Reads and writes `Settings` as JSON under one UserDefaults key.
public final class SettingsStore {
    public static let defaultsKey = "ScrollSwitchSettings"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> Settings {
        guard let data = defaults.data(forKey: Self.defaultsKey) else { return Settings() }
        return (try? JSONDecoder().decode(Settings.self, from: data)) ?? Settings()
    }

    public func save(_ settings: Settings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }

    public func reset() {
        defaults.removeObject(forKey: Self.defaultsKey)
    }
}
