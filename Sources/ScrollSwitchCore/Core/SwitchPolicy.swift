import Foundation

/// Edge-triggered apply rules. Pure, so the "act on changes, not constantly" behavior and
/// every pause mode can be unit tested without hardware or timers.
public struct SwitchPolicy: Equatable, Sendable {
    public enum Outcome: Equatable, Sendable {
        /// Set Natural scrolling to `natural` because the state is now `state`.
        case apply(DockState, natural: Bool)
        /// The state has not changed since it was last applied, so leave the user's setting alone.
        case unchanged(DockState)
        /// Automatic switching is paused.
        case paused(DockState)
    }

    public private(set) var lastAppliedState: DockState?

    public init(lastAppliedState: DockState? = nil) {
        self.lastAppliedState = lastAppliedState
    }

    /// - Parameters:
    ///   - force: Apply even if the state looks the same (launch, wake, resume).
    ///   - settings: May be modified: an expired or satisfied pause is cleared.
    public mutating func decide(state: DockState, force: Bool, settings: inout SwitchSettings, now: Date) -> Outcome {
        var force = force

        let wasPaused = settings.pause != .none
        settings.pause = settings.pause.resolved(now: now)
        if case .untilNextChange(let from) = settings.pause, state != from {
            settings.pause = .none
        }
        if wasPaused && settings.pause == .none {
            // The pause just ended: bring the setting in line with reality.
            force = true
        }
        if settings.pause != .none { return .paused(state) }

        if !force && state == lastAppliedState { return .unchanged(state) }
        lastAppliedState = state
        return .apply(state, natural: settings.natural(for: state))
    }
}
