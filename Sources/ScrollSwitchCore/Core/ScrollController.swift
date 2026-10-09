import Foundation

/// Why the last decision ended in no change, so the menu can explain itself.
public enum SkipReason: Equatable, Sendable {
    case unsupported
    case paused
    case forced(ScrollDirection)
    case manualOverride
    case alreadyCorrect

    public var message: String {
        switch self {
        case .unsupported: return "Scroll API unavailable on this macOS"
        case .paused: return "Automation paused"
        case .forced(let direction): return "Forced \(direction.displayName)"
        case .manualOverride: return "Manual override (until next dock change)"
        case .alreadyCorrect: return "Already correct"
        }
    }
}

/// Decides whether to touch the setting, and is the only caller of ScrollSetter.apply.
///
/// Spec sections 6.2 and 6.5. Three things can stop it: automation paused, a direction
/// forced from the menu, or a manual override detected from System Settings.
public final class ScrollController {
    private let setter: ScrollSetting
    private let log: EventLog
    private let settingsProvider: () -> Settings

    public private(set) var manualOverride = false
    public private(set) var forcedDirection: ScrollDirection?
    public private(set) var lastSkipReason: SkipReason?

    /// Something the menu bar should redraw for.
    public var onStateChange: (() -> Void)?
    /// A direction was actually written, for the optional notification (FR-14).
    public var onDirectionApplied: ((ScrollDirection) -> Void)?

    public init(setter: ScrollSetting, log: EventLog, settings: @escaping () -> Settings) {
        self.setter = setter
        self.log = log
        self.settingsProvider = settings
    }

    public var currentDirection: ScrollDirection { setter.current }
    public var isSupported: Bool { setter.isSupported }
    public var unsupportedReason: String? { setter.unsupportedReason }

    // MARK: - Inputs

    /// A genuine Docked/Undocked transition (FR-6). This is also the moment a manual
    /// override expires (FR-11 step 3).
    public func handleTransition(to state: DockState) {
        if manualOverride {
            manualOverride = false
            log.append(.state, "Dock change to \(state.displayName): manual override cleared")
        }
        log.append(.state, "Now \(state.displayName)")
        apply(target(for: state), trigger: state.displayName, respectOverride: false)
    }

    /// Launch, wake, or a debounce window that settled where it started. Corrects drift
    /// without picking a fight with a manual change.
    public func reconcile(with state: DockState, trigger: String) {
        apply(target(for: state), trigger: trigger, respectOverride: true)
    }

    /// Force Natural / Force Traditional from the menu. Applies even while paused, and
    /// pins the direction until automation is resumed.
    public func force(_ direction: ScrollDirection) {
        forcedDirection = direction
        manualOverride = false
        log.append(.direction, "Forced \(direction.displayName) from the menu")
        write(direction, trigger: "Force \(direction.displayName)")
        lastSkipReason = .forced(direction)
        onStateChange?()
    }

    /// Back to following the dock state.
    public func resumeAutomatic(currentState: DockState?) {
        guard forcedDirection != nil else { return }
        forcedDirection = nil
        lastSkipReason = nil
        log.append(.direction, "Force cleared; following the dock state again")
        if let currentState {
            apply(target(for: currentState), trigger: "Force cleared", respectOverride: true)
        }
        onStateChange?()
    }

    /// SwipeScrollDirectionDidChangeNotification arrived (FR-11 steps 1 and 2).
    public func externalChangeDetected() {
        // Our own apply posts the same notification, so ignore the echo.
        guard !setter.didWeJustWrite() else { return }

        manualOverride = true
        lastSkipReason = .manualOverride
        log.append(
            .direction,
            "Changed outside ScrollSwitch to \(setter.current.displayName): backing off until the next dock change"
        )
        onStateChange?()
    }

    // MARK: - Applying

    private func target(for state: DockState) -> ScrollDirection {
        settingsProvider().direction(for: state)
    }

    private func apply(_ direction: ScrollDirection, trigger: String, respectOverride: Bool) {
        if let forced = forcedDirection {
            skip(.forced(forced), "\(trigger): direction is forced to \(forced.displayName)")
            return
        }
        if respectOverride, manualOverride {
            skip(.manualOverride, "\(trigger): manual override in effect, leaving it alone")
            return
        }
        guard settingsProvider().automationEnabled else {
            skip(.paused, "\(trigger): automation is paused")
            return
        }
        write(direction, trigger: trigger)
    }

    private func write(_ direction: ScrollDirection, trigger: String) {
        guard setter.isSupported else {
            skip(.unsupported, "\(trigger): cannot apply, \(setter.unsupportedReason ?? "scroll API unavailable")")
            return
        }
        guard setter.current != direction else {
            skip(.alreadyCorrect, "\(trigger): already \(direction.displayName), skipping")
            return
        }

        setter.apply(direction)
        lastSkipReason = nil
        log.append(.direction, "\(trigger): applied \(direction.displayName)")
        onDirectionApplied?(direction)
        onStateChange?()
    }

    private func skip(_ reason: SkipReason, _ message: String) {
        lastSkipReason = reason
        log.append(.direction, message)
        onStateChange?()
    }
}
