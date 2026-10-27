import IOKit

/// Reads the lid state from `AppleClamshellState` on IOPMrootDomain.
public enum LidState {
    /// true = lid closed, false = open, nil = no lid (desktop Mac) or unreadable.
    public static func isClosed() -> Bool? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        let value = IORegistryEntryCreateCFProperty(service, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)
        return value?.takeRetainedValue() as? Bool
    }

    /// Lid open, falling back to "built-in display online" when the registry has no answer.
    public static func isOpen(snapshot: DisplaySnapshot) -> Bool {
        if let closed = isClosed() { return !closed }
        return snapshot.builtinOnline
    }
}
