import AppKit
import Combine
import Foundation

/// Owns every piece and publishes what the menu bar needs. One instance per app.
///
/// Deliberately not @MainActor: every callback it subscribes to already arrives on the
/// main queue, and staying non-isolated keeps the C-callback plumbing simple.
public final class ScrollSwitchCoordinator: ObservableObject {
    @Published public private(set) var settings: Settings
    @Published public private(set) var dockState: DockState?
    @Published public private(set) var isPending = false
    @Published public private(set) var direction: ScrollDirection = .natural
    @Published public private(set) var displays: [DisplayInfo] = []
    @Published public private(set) var mice: [MouseInfo] = []
    @Published public private(set) var lidClosed: Bool?
    @Published public private(set) var skipReason: SkipReason?
    @Published public private(set) var launchAtLoginStatus = ""

    public let log: EventLog

    private let store: SettingsStore
    private let setter: ScrollSetting
    private let detector: DockDetector
    private var controller: ScrollController!

    private let displayMonitor = DisplayMonitor()
    private let deviceMonitor = DeviceMonitor()
    private let lidMonitor = LidMonitor()
    private let powerMonitor = PowerMonitor()
    private let changeWatcher = ScrollChangeWatcher()
    private let notifier = Notifier()

    private var started = false

    public init(
        store: SettingsStore = SettingsStore(),
        setter: ScrollSetting = ScrollSetter(),
        log: EventLog = EventLog()
    ) {
        let loaded = store.load()
        self.store = store
        self.setter = setter
        self.log = log
        self.settings = loaded
        self.detector = DockDetector(settings: loaded)
        self.direction = setter.current
        self.controller = ScrollController(setter: setter, log: log) { [weak self] in
            self?.settings ?? loaded
        }
    }

    // MARK: - Lifecycle

    public func start() {
        guard !started else { return }
        started = true

        log.append(.app, "ScrollSwitch starting")
        if let reason = setter.unsupportedReason {
            log.append(.error, "Scroll API unavailable: \(reason)")
        } else if let resolved = (setter as? ScrollSetter)?.resolvedSymbol {
            log.append(.app, "Resolved \(resolved) in PreferencePanesSupport")
        }

        wireDetector()
        wireController()
        wireMonitors()

        displayMonitor.start()
        deviceMonitor.start()
        powerMonitor.start()
        changeWatcher.start()

        if settings.notifyOnChange { notifier.requestAuthorizationIfNeeded() }
        if settings.launchAtLogin, !LaunchAtLogin.isEnabled { applyLaunchAtLogin() }
        launchAtLoginStatus = LaunchAtLogin.statusDescription

        reevaluate(trigger: "Launch")
    }

    public func stop() {
        displayMonitor.stop()
        deviceMonitor.stop()
        powerMonitor.stop()
        changeWatcher.stop()
        started = false
        log.append(.app, "ScrollSwitch stopping")
    }

    private func wireDetector() {
        detector.onTransition = { [weak self] state, _ in
            guard let self else { return }
            self.dockState = state
            self.controller.handleTransition(to: state)
            self.refresh()
        }
        detector.onSettleWithoutChange = { [weak self] state, _ in
            guard let self else { return }
            self.log.append(.state, "Settled back on \(state.displayName); nothing applied")
            self.refresh()
        }
        detector.onPendingChange = { [weak self] pending in
            self?.isPending = pending
        }
    }

    private func wireController() {
        controller.onStateChange = { [weak self] in self?.refresh() }
        controller.onDirectionApplied = { [weak self] direction in
            guard let self, self.settings.notifyOnChange else { return }
            self.notifier.post(
                title: "ScrollSwitch",
                body: "Scrolling is now \(direction.displayName)"
            )
        }
    }

    private func wireMonitors() {
        displayMonitor.onChange = { [weak self] displays in
            guard let self else { return }
            self.log.append(.display, Self.describe(displays: displays))
            self.submitSignals()
        }
        deviceMonitor.onChange = { [weak self] mice in
            guard let self else { return }
            self.log.append(.device, Self.describe(mice: mice))
            self.submitSignals()
        }
        powerMonitor.onWake = { [weak self] label in
            guard let self else { return }
            self.log.append(.power, "Woke (\(label)); re-scanning")
            self.reevaluate(trigger: "Wake")
        }
        powerMonitor.onSleep = { [weak self] in
            self?.log.append(.power, "Going to sleep")
        }
        changeWatcher.onChange = { [weak self] in
            self?.controller.externalChangeDetected()
        }
    }

    // MARK: - Signals

    @discardableResult
    private func refreshSignals() -> SignalSnapshot {
        let allDisplays = displayMonitor.snapshot()
        let allMice = deviceMonitor.snapshot()
        let lid = lidMonitor.snapshot()

        displays = allDisplays
        mice = allMice
        lidClosed = lid

        return SignalSnapshot(
            externalDisplays: allDisplays.filter { !$0.isBuiltin },
            externalMice: allMice.filter { !$0.isBuiltIn },
            lidClosed: lid
        )
    }

    private func submitSignals() {
        detector.submit(refreshSignals())
        refresh()
    }

    /// Decide now and correct the setting if it drifted. Used on launch, on wake, and
    /// whenever the rule changes (FR-7).
    public func reevaluate(trigger: String) {
        let previous = detector.state
        detector.reevaluate(refreshSignals())

        // A changed state already went through onTransition. An unchanged one still gets
        // reconciled, which is what fixes a wrong direction after a crash or a reboot.
        if let state = detector.state, state == previous {
            controller.reconcile(with: state, trigger: trigger)
        }
        refresh()
    }

    private func refresh() {
        dockState = detector.state
        direction = setter.current
        skipReason = controller.lastSkipReason
    }

    // MARK: - Menu actions

    public var isSupported: Bool { setter.isSupported }
    public var unsupportedReason: String? { setter.unsupportedReason }
    public var forcedDirection: ScrollDirection? { controller.forcedDirection }
    public var manualOverride: Bool { controller.manualOverride }

    public var externalDisplays: [DisplayInfo] {
        displays.filter { display in !display.isBuiltin }
    }

    public var externalMice: [MouseInfo] {
        mice.filter { mouse in !mouse.isBuiltIn }
    }

    public func force(_ direction: ScrollDirection) {
        controller.force(direction)
        refresh()
    }

    public func resumeAutomatic() {
        controller.resumeAutomatic(currentState: detector.state)
        refresh()
    }

    public func setAutomationEnabled(_ enabled: Bool) {
        update { settings in settings.automationEnabled = enabled }
        log.append(.app, enabled ? "Automation resumed" : "Automation paused")
        if enabled, let state = detector.state {
            controller.reconcile(with: state, trigger: "Automation resumed")
        }
        refresh()
    }

    /// FR-10. Records whatever external displays and pointers are attached right now
    /// and switches the rule over to markers.
    public func learnMyDock() {
        let learnedDisplays = externalDisplays
        let learnedMice = externalMice

        update { settings in
            settings.markerDisplays = learnedDisplays.map(\.identity)
            settings.markerMice = learnedMice.map(\.identity)
            var labels = settings.markerLabels
            for display in learnedDisplays { labels[display.identity.id] = display.name }
            for mouse in learnedMice { labels[mouse.identity.id] = mouse.name }
            settings.markerLabels = labels
            settings.rule = .markers
        }

        log.append(
            .app,
            "Learned dock: \(learnedDisplays.count) display(s), \(learnedMice.count) pointer(s); rule is now dock markers"
        )
    }

    public func forgetMarkers() {
        update { settings in
            settings.markerDisplays = []
            settings.markerMice = []
            settings.markerLabels = [:]
            settings.rule = .anyExternalDisplay
        }
        log.append(.app, "Dock markers cleared; rule is back to any external display")
    }

    public func removeMarker(display: DisplayID) {
        update { settings in
            settings.markerDisplays.removeAll { marker in marker == display }
            settings.markerLabels[display.id] = nil
        }
    }

    public func removeMarker(mouse: MouseID) {
        update { settings in
            settings.markerMice.removeAll { marker in marker == mouse }
            settings.markerLabels[mouse.id] = nil
        }
    }

    /// The single funnel for settings changes: persist, push to the detector, and
    /// re-decide when the change could have changed the answer.
    public func update(_ transform: (inout Settings) -> Void) {
        var updated = settings
        transform(&updated)
        guard updated != settings else { return }

        let launchChanged = updated.launchAtLogin != settings.launchAtLogin
        let notifyTurnedOn = updated.notifyOnChange && !settings.notifyOnChange
        let ruleChanged = updated.rule != settings.rule
            || updated.requireLidClosed != settings.requireLidClosed
            || updated.markerDisplays != settings.markerDisplays
            || updated.markerMice != settings.markerMice

        settings = updated
        store.save(updated)
        detector.updateSettings(updated)

        if launchChanged { applyLaunchAtLogin() }
        if notifyTurnedOn { notifier.requestAuthorizationIfNeeded() }
        if ruleChanged, started { reevaluate(trigger: "Rule changed") }
    }

    private func applyLaunchAtLogin() {
        if let error = LaunchAtLogin.set(settings.launchAtLogin) {
            log.append(.error, "Launch at login change failed: \(error.localizedDescription)")
        }
        launchAtLoginStatus = LaunchAtLogin.statusDescription
    }

    // MARK: - Log helpers

    private static func describe(displays: [DisplayInfo]) -> String {
        let external = displays.filter { display in !display.isBuiltin }
        guard !external.isEmpty else { return "No external displays" }
        let names = external.map { display in display.name }
        return "External displays: " + names.joined(separator: ", ")
    }

    private static func describe(mice: [MouseInfo]) -> String {
        let external = mice.filter { mouse in !mouse.isBuiltIn }
        guard !external.isEmpty else { return "No external pointers" }
        let names = external.map { mouse in "\(mouse.name) [\(mouse.transport)]" }
        return "External pointers: " + names.joined(separator: ", ")
    }
}
