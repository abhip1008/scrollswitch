import Foundation

public enum TogglerError: Error, CustomStringConvertible {
    case frameworkMissing
    case symbolMissing(String)

    public var description: String {
        switch self {
        case .frameworkMissing: return "PreferencePanesSupport.framework could not be loaded"
        case .symbolMissing(let name): return "\(name) is missing from PreferencePanesSupport"
        }
    }
}

/// Reads and sets the system Natural scrolling value. Hides which method is used.
public protocol ScrollToggling: AnyObject {
    var methodName: String { get }
    var isNatural: Bool { get }
    func write(_ on: Bool)
}

extension ScrollToggling {
    /// Sets the value only if it differs. Returns true when the value now matches `on`.
    @discardableResult
    public func setNatural(_ on: Bool) -> Bool {
        guard isNatural != on else { return true }
        write(on)
        return isNatural == on
    }
}

/// The method System Settings uses: a private function that stores the value and applies
/// it live. Confirmed on macOS 27.0.1 (see docs/hardware-notes.md).
public final class PrivateAPIToggler: ScrollToggling {
    private typealias SetFn = @convention(c) (Bool) -> Void
    private typealias GetFn = @convention(c) () -> Bool

    static let frameworkPath = "/System/Library/PrivateFrameworks/PreferencePanesSupport.framework/PreferencePanesSupport"

    private let setFn: SetFn
    private let getFn: GetFn

    public let methodName = "private API"

    public init() throws {
        guard let handle = dlopen(Self.frameworkPath, RTLD_LAZY) else { throw TogglerError.frameworkMissing }
        guard let s = dlsym(handle, "setSwipeScrollDirection") else { throw TogglerError.symbolMissing("setSwipeScrollDirection") }
        guard let g = dlsym(handle, "swipeScrollDirection") else { throw TogglerError.symbolMissing("swipeScrollDirection") }
        setFn = unsafeBitCast(s, to: SetFn.self)
        getFn = unsafeBitCast(g, to: GetFn.self)
    }

    public var isNatural: Bool { getFn() }
    public func write(_ on: Bool) { setFn(on) }
}

/// Backup method A: write the global preference and post the change notification. Only
/// used if the private function disappears. Whether it applies live depends on the macOS
/// version, so the app shows a warning while this is active.
public final class PreferencesToggler: ScrollToggling {
    private let key = "com.apple.swipescrolldirection" as CFString
    public let methodName = "preferences + notification (backup)"

    public init() {}

    public var isNatural: Bool {
        CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
        let value = CFPreferencesCopyValue(key, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        // macOS treats a missing value as Natural ON.
        return (value as? Bool) ?? true
    }

    public func write(_ on: Bool) {
        // Never use setPersistentDomain on the global domain: it wipes unrelated settings.
        CFPreferencesSetValue(key, on as CFBoolean, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("SwipeScrollDirectionDidChangeNotification"),
            object: nil, userInfo: nil, deliverImmediately: true)
    }
}

public enum ScrollTogglerFactory {
    /// The best available method, plus the reason the preferred one failed (if it did).
    public static func makeBest() -> (toggler: ScrollToggling, warning: String?) {
        do {
            return (try PrivateAPIToggler(), nil)
        } catch {
            return (PreferencesToggler(), "Live toggle unavailable on this macOS (\(error)). Using backup method.")
        }
    }
}
