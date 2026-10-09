import Foundation
import IOKit

/// Reads the clamshell (lid) state out of the IOPMrootDomain registry entry.
///
/// Optional signal: on a desktop Mac the key is absent and this returns nil, which the
/// docking rule treats as "no lid information".
public final class LidMonitor {
    public init() {}

    public func snapshot() -> Bool? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPMrootDomain")
        )
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        let property = IORegistryEntryCreateCFProperty(
            service,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue()

        return (property as? NSNumber)?.boolValue
    }

    public func describe() -> String {
        switch snapshot() {
        case .some(true): return "Closed"
        case .some(false): return "Open"
        case nil: return "Unknown"
        }
    }
}
