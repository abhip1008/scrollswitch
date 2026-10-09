import Foundation

/// Turns a stream of noisy signal changes into clean Docked/Undocked transitions.
///
/// Spec sections 6.3 and 6.4. A KVM typically adds and removes devices several times
/// while it switches, and monitors take a moment to come up, so every signal change goes
/// through a debounce window. If the window settles back on the state it started from,
/// nothing is emitted.
public final class DockDetector {
    public private(set) var state: DockState?
    public private(set) var isPending = false
    public private(set) var latest = SignalSnapshot.empty

    /// Fired only for a real undocked -> docked or docked -> undocked change.
    public var onTransition: ((DockState, SignalSnapshot) -> Void)?
    /// Fired when the debounce window settles on the state it was already in.
    public var onSettleWithoutChange: ((DockState, SignalSnapshot) -> Void)?
    public var onPendingChange: ((Bool) -> Void)?

    private var settings: Settings
    private let scheduler: DebounceScheduler

    public init(settings: Settings = Settings(), scheduler: DebounceScheduler = MainQueueDebouncer()) {
        self.settings = settings
        self.scheduler = scheduler
    }

    public func updateSettings(_ settings: Settings) {
        self.settings = settings
    }

    /// A monitor saw something change. Debounced.
    public func submit(_ snapshot: SignalSnapshot) {
        latest = snapshot

        // On the very first signal there is no state to protect, and the app needs an
        // answer immediately, so skip the window.
        guard state != nil else {
            settle()
            return
        }

        setPending(true)
        scheduler.schedule(after: settings.debounceSeconds) { [weak self] in
            self?.settle()
        }
    }

    /// Launch, wake, or a rule change: decide right now, no debounce (FR-7).
    public func reevaluate(_ snapshot: SignalSnapshot) {
        latest = snapshot
        scheduler.cancel()
        settle()
    }

    /// Forget the current state so the next submit is treated as a first evaluation.
    public func reset() {
        scheduler.cancel()
        setPending(false)
        state = nil
    }

    private func settle() {
        setPending(false)
        let resolved: DockState = Self.isDocked(snapshot: latest, settings: settings) ? .docked : .undocked

        guard resolved != state else {
            if let state { onSettleWithoutChange?(state, latest) }
            return
        }

        state = resolved
        onTransition?(resolved, latest)
    }

    private func setPending(_ value: Bool) {
        guard isPending != value else { return }
        isPending = value
        onPendingChange?(value)
    }

    // MARK: - The rule

    /// The rule actually in force. Markers with nothing learned yet would never be true,
    /// so it degrades to the out-of-the-box rule rather than silently doing nothing.
    public static func effectiveRule(for settings: Settings) -> DockRule {
        if settings.rule == .markers,
           settings.markerDisplays.isEmpty,
           settings.markerMice.isEmpty {
            return .anyExternalDisplay
        }
        return settings.rule
    }

    /// Pure, so the whole decision table is unit testable. Spec section 6.3.
    public static func isDocked(snapshot: SignalSnapshot, settings: Settings) -> Bool {
        var docked: Bool

        switch effectiveRule(for: settings) {
        case .anyExternalDisplay:
            docked = !snapshot.externalDisplays.isEmpty

        case .anyExternalMouse:
            docked = !snapshot.externalMice.isEmpty

        case .markers:
            let displayMatch = snapshot.externalDisplays.contains {
                settings.markerDisplays.contains($0.identity)
            }
            let mouseMatch = snapshot.externalMice.contains {
                settings.markerMice.contains($0.identity)
            }
            docked = displayMatch || mouseMatch
        }

        // The lid modifier only ever makes docking harder, never easier. Unknown lid
        // state (desktop Mac) counts as not closed.
        if settings.requireLidClosed {
            docked = docked && (snapshot.lidClosed ?? false)
        }

        return docked
    }
}
