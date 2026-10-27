import Foundation

/// Persists `SwitchSettings` as JSON in the app's own UserDefaults (never the global domain).
public final class SettingsStore {
    private let defaults: UserDefaults
    private let key = "settings.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> SwitchSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(SwitchSettings.self, from: data) else {
            return SwitchSettings()
        }
        return settings
    }

    public func save(_ settings: SwitchSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: key)
        }
    }

    public func bool(_ key: String) -> Bool { defaults.bool(forKey: key) }
    public func set(_ value: Bool, for key: String) { defaults.set(value, forKey: key) }

    public func dates(_ key: String) -> [Date] { (defaults.array(forKey: key) as? [Date]) ?? [] }
    public func set(_ value: [Date], for key: String) { defaults.set(value, forKey: key) }
}
