import Foundation

/// Everything that can read and write the system Natural scrolling value.
/// ScrollController talks to this protocol so tests never touch the real setting.
public protocol ScrollSetting: AnyObject {
    var isSupported: Bool { get }
    var unsupportedReason: String? { get }
    var current: ScrollDirection { get }
    var lastWriteByUs: Date { get }
    func apply(_ direction: ScrollDirection)
}

extension ScrollSetting {
    /// True if we wrote the value recently enough that an incoming change
    /// notification is almost certainly our own echo, not the user in System Settings.
    public func didWeJustWrite(within seconds: TimeInterval = 1.0) -> Bool {
        Date().timeIntervalSince(lastWriteByUs) < seconds
    }
}

/// The only component that touches the real system setting. Spec section 7.
///
/// Three steps per apply:
///   1. private `setSwipeScrollDirection(Bool)` from PreferencePanesSupport -- the live change
///   2. write `com.apple.swipescrolldirection` in the global domain -- the stored value
///   3. post `SwipeScrollDirectionDidChangeNotification` -- so System Settings redraws
///
/// The private function is resolved with dlopen/dlsym at runtime rather than linked, so a
/// macOS release that removes it leaves us with a clear error instead of a launch crash.
public final class ScrollSetter: ScrollSetting {
    private typealias SetSwipeFn = @convention(c) (Bool) -> Void

    public static let preferenceKey = "com.apple.swipescrolldirection" as CFString
    public static let changedNotification = Notification.Name("SwipeScrollDirectionDidChangeNotification")

    /// Shared-cache paths are still valid dlopen arguments even though no file exists on disk.
    static let frameworkPaths = [
        "/System/Library/PrivateFrameworks/PreferencePanesSupport.framework/PreferencePanesSupport",
        "/System/Library/PrivateFrameworks/PreferencePanesSupport.framework/Versions/A/PreferencePanesSupport",
    ]

    /// Spec section 7.2 step 1: if Apple renames it, try the obvious spellings before giving up.
    static let symbolNames = [
        "setSwipeScrollDirection",
        "SetSwipeScrollDirection",
        "_setSwipeScrollDirection",
    ]

    private let setSwipe: SetSwipeFn?

    public private(set) var unsupportedReason: String?
    public private(set) var lastWriteByUs = Date.distantPast

    /// Which path and symbol actually resolved, for the Status tab in Preferences.
    public private(set) var resolvedPath: String?
    public private(set) var resolvedSymbol: String?

    public init() {
        var fn: SetSwipeFn?
        var lastError = "PreferencePanesSupport could not be opened"

        for path in Self.frameworkPaths {
            guard let handle = dlopen(path, RTLD_LAZY) else {
                if let err = dlerror() { lastError = String(cString: err) }
                continue
            }
            for symbol in Self.symbolNames {
                guard let sym = dlsym(handle, symbol) else { continue }
                fn = unsafeBitCast(sym, to: SetSwipeFn.self)
                resolvedPath = path
                resolvedSymbol = symbol
                break
            }
            if fn != nil { break }
            lastError = "Opened \(path) but found no setSwipeScrollDirection symbol"
        }

        setSwipe = fn
        unsupportedReason = fn == nil ? lastError : nil
    }

    public var isSupported: Bool { setSwipe != nil }

    /// macOS default when the key has never been written is natural.
    public var current: ScrollDirection {
        CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
        let raw = CFPreferencesCopyAppValue(Self.preferenceKey, kCFPreferencesAnyApplication)
        guard let number = raw as? NSNumber else { return .natural }
        return ScrollDirection(isNatural: number.boolValue)
    }

    public func apply(_ direction: ScrollDirection) {
        let natural = direction.isNatural
        lastWriteByUs = Date()

        // 1. The live change. Without this the behaviour only updates after logout.
        setSwipe?(natural)

        // 2. Make the stored value match. Never use setPersistentDomain on the global
        //    domain -- it has been reported to wipe unrelated global settings.
        let value: CFBoolean = natural ? kCFBooleanTrue : kCFBooleanFalse
        CFPreferencesSetAppValue(Self.preferenceKey, value, kCFPreferencesAnyApplication)
        CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)

        // 3. Let an open System Settings window update its checkbox.
        DistributedNotificationCenter.default().postNotificationName(
            Self.changedNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }
}

/// In-memory stand-in used by SwiftUI previews, the spike dry run, and tests.
public final class MemoryScrollSetter: ScrollSetting {
    public private(set) var applied: [ScrollDirection] = []
    public var isSupported: Bool
    public var unsupportedReason: String?
    public private(set) var current: ScrollDirection
    public private(set) var lastWriteByUs = Date.distantPast

    public init(current: ScrollDirection = .natural, isSupported: Bool = true) {
        self.current = current
        self.isSupported = isSupported
        self.unsupportedReason = isSupported ? nil : "Simulated unsupported macOS"
    }

    public func apply(_ direction: ScrollDirection) {
        lastWriteByUs = Date()
        current = direction
        applied.append(direction)
    }

    /// Simulates the user flipping the checkbox in System Settings.
    public func setExternally(_ direction: ScrollDirection) {
        current = direction
    }

    public func reset() {
        applied.removeAll()
    }

    /// Ages the last write so a change notification is no longer mistaken for our own
    /// echo. Lets tests exercise the manual-override path without sleeping.
    public func pretendLastWriteWasLongAgo() {
        lastWriteByUs = .distantPast
    }
}
