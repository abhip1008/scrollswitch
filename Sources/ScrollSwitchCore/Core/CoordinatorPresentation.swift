import Foundation

/// Everything the menu bar and Preferences display, kept out of the wiring above.
extension ScrollSwitchCoordinator {
    /// Spec section 9.1.
    public var menuBarSymbol: String {
        if !isSupported { return "exclamationmark.triangle" }
        if !settings.automationEnabled || forcedDirection != nil || manualOverride {
            return "pause.circle"
        }
        return direction == .traditional ? "computermouse" : "hand.point.up.left"
    }

    public var stateLine: String {
        guard let state = dockState else { return "ScrollSwitch: Evaluating" }
        return isPending
            ? "ScrollSwitch: \(state.displayName) (settling)"
            : "ScrollSwitch: \(state.displayName)"
    }

    public var directionLine: String {
        "Scrolling: \(direction.displayName)"
    }

    /// One short line explaining why nothing is happening, if anything is in the way.
    public var statusNote: String? {
        if let reason = unsupportedReason { return reason }
        return skipReason?.message
    }

    public var lidLine: String {
        switch lidClosed {
        case .some(true): return "Lid: Closed"
        case .some(false): return "Lid: Open"
        case nil: return "Lid: Unknown"
        }
    }

    public var ruleLine: String {
        let effective = DockDetector.effectiveRule(for: settings)
        var text = "Rule: \(effective.displayName)"
        if effective != settings.rule { text += " (nothing learned yet)" }
        if settings.requireLidClosed { text += ", lid must be closed" }
        return text
    }

    public func isMarker(_ display: DisplayInfo) -> Bool {
        settings.markerDisplays.contains(display.identity)
    }

    public func isMarker(_ mouse: MouseInfo) -> Bool {
        settings.markerMice.contains(mouse.identity)
    }

    public func detectedLabel(_ display: DisplayInfo) -> String {
        isMarker(display) ? "\(display.name) (dock marker)" : display.name
    }

    public func detectedLabel(_ mouse: MouseInfo) -> String {
        isMarker(mouse) ? "\(mouse.name) (dock marker)" : mouse.name
    }
}
