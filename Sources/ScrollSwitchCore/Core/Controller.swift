import AppKit
import Combine

/// Where the controller reads the world from. Swapped for a fake in tests.
public protocol SystemProbe {
    func snapshot() -> DisplaySnapshot
    func usbPresent() -> Set<USBDeviceID>
    func lidOpen(snapshot: DisplaySnapshot) -> Bool
}

public struct LiveSystemProbe: SystemProbe {
    public let usb: USBMonitor

    public init(usb: USBMonitor) {
        self.usb = usb
    }

    public func snapshot() -> DisplaySnapshot { DisplayMonitor.takeSnapshot() }
    public func usbPresent() -> Set<USBDeviceID> { usb.present.isEmpty ? USBMonitor.scan() : usb.present }
    public func lidOpen(snapshot: DisplaySnapshot) -> Bool { LidState.isOpen(snapshot: snapshot) }
}

/// Collects events, waits for things to settle, asks the evaluator, tells the toggler, logs it.
@MainActor
public final class Controller: ObservableObject {
    public struct Timing {
        /// Quiet period after a display or USB event before deciding.
        public var settle: TimeInterval = 2
        /// Longer settle after wake, because monitors take longer to show up.
        public var wake: TimeInterval = 3.5
        /// Second look after launch, in case displays were not ready at login.
        public var launchRecheck: TimeInterval = 5
        /// Delay before retrying a set call that did not stick.
        public var retry: TimeInterval = 1
        /// How often to refresh the displayed Natural value and check timed pauses.
        public var tick: TimeInterval = 15

        public init() {}
    }

    // MARK: Published state

    @Published public private(set) var dockState: DockState?
    @Published public private(set) var isNatural: Bool
    @Published public private(set) var snapshot = DisplaySnapshot(displays: [])
    @Published public private(set) var usbPresent: Set<USBDeviceID> = []
    @Published public private(set) var lidOpen = true
    /// Set when the toggler is not the live private API.
    @Published public private(set) var togglerWarning: String?
    /// Set when a set call did not stick, even after a retry.
    @Published public private(set) var applyFailed = false
    @Published public private(set) var stats: SwitchStats
    @Published public var settings: SwitchSettings {
        didSet { settingsChanged(from: oldValue) }
    }

    public var externalCount: Int { snapshot.externals.count }
    public var isPaused: Bool { settings.pause.isActive(now: now()) }
    public var lastEvent: LogEvent? { log.latest }
    public var togglerMethod: String { toggler.methodName }

    public let log: EventLog

    // MARK: Dependencies

    private let toggler: ScrollToggling
    private let probe: SystemProbe
    private let store: SettingsStore
    private let notifier: Notifier?
    private let timing: Timing
    private let now: () -> Date

    private var displayMonitor: DisplayMonitor?
    private var usbMonitor: USBMonitor?
    private var powerMonitor: PowerMonitor?

    private var policy = SwitchPolicy()
    private var pending: DispatchWorkItem?
    private var pendingDeadline: Date?
    private var pendingForce = false
    private var pendingReasons: [String] = []
    private var tickTimer: Timer?
    private var started = false

    private static let statsKey = "stats.switches"

    public init(toggler: ScrollToggling,
                togglerWarning: String? = nil,
                probe: SystemProbe,
                store: SettingsStore = SettingsStore(),
                notifier: Notifier? = nil,
                log: EventLog? = nil,
                timing: Timing = Timing(),
                now: @escaping () -> Date = Date.init) {
        self.toggler = toggler
        self.togglerWarning = togglerWarning
        self.probe = probe
        self.store = store
        self.notifier = notifier
        self.log = log ?? EventLog()
        self.timing = timing
        self.now = now
        self.settings = store.load()
        self.isNatural = toggler.isNatural
        self.stats = SwitchStats(switches: store.dates(Self.statsKey))
    }

    /// The real app wiring: private API toggler (or backup), live monitors.
    public static func live(store: SettingsStore = SettingsStore(), log: EventLog? = nil) -> Controller {
        let (toggler, warning) = ScrollTogglerFactory.makeBest()
        let usb = USBMonitor()
        let controller = Controller(toggler: toggler, togglerWarning: warning, probe: LiveSystemProbe(usb: usb), store: store,
                                    notifier: Notifier(), log: log)
        controller.usbMonitor = usb
        controller.displayMonitor = DisplayMonitor()
        controller.powerMonitor = PowerMonitor()
        return controller
    }

    // MARK: Lifecycle

    public func start() {
        guard !started else { return }
        started = true
        if let togglerWarning { log.add(.warning, togglerWarning) }
        log.add(.info, "Started (toggle method: \(toggler.methodName))")

        displayMonitor?.onChange = { [weak self] reason in self?.scheduleEvaluation(reason: reason) }
        usbMonitor?.onChange = { [weak self] reason in self?.scheduleEvaluation(reason: reason) }
        powerMonitor?.onWake = { [weak self] reason in
            guard let self else { return }
            self.scheduleEvaluation(reason: reason, delay: self.timing.wake, force: true)
        }
        powerMonitor?.onSleep = { [weak self] in self?.cancelPending() }
        displayMonitor?.start()
        usbMonitor?.start()
        powerMonitor?.start()

        evaluateAndApply(reason: "launch", force: true)
        scheduleEvaluation(reason: "launch recheck", delay: timing.launchRecheck)

        let timer = Timer(timeInterval: timing.tick, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    public func stop() {
        displayMonitor?.stop()
        usbMonitor?.stop()
        powerMonitor?.stop()
        tickTimer?.invalidate()
        tickTimer = nil
        cancelPending()
        started = false
    }

    // MARK: Debounce

    /// Every event pushes the decision back until things have been quiet for `delay`.
    /// A pending forced or longer (wake) evaluation keeps its force flag and its deadline.
    public func scheduleEvaluation(reason: String, delay: TimeInterval? = nil, force: Bool = false) {
        let delay = delay ?? timing.settle
        var deadline = now().addingTimeInterval(delay)
        if let pendingDeadline, pendingDeadline > deadline { deadline = pendingDeadline }
        pending?.cancel()

        pendingForce = pendingForce || force
        if !pendingReasons.contains(reason) { pendingReasons.append(reason) }
        pendingDeadline = deadline

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let reasons = self.pendingReasons
            let force = self.pendingForce
            self.clearPending()
            self.evaluateAndApply(reason: Self.summarize(reasons), force: force)
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, deadline.timeIntervalSince(now())), execute: work)
    }

    public var hasPendingEvaluation: Bool { pending != nil }

    private func cancelPending() {
        pending?.cancel()
        clearPending()
    }

    private func clearPending() {
        pending = nil
        pendingDeadline = nil
        pendingForce = false
        pendingReasons = []
    }

    private static func summarize(_ reasons: [String]) -> String {
        guard let first = reasons.first else { return "change" }
        return reasons.count == 1 ? first : "\(first) (+\(reasons.count - 1) more events)"
    }

    // MARK: Decide and apply

    /// Snapshot, evaluate, and apply if the policy says so.
    public func evaluateAndApply(reason: String, force: Bool = false) {
        let snap = probe.snapshot()
        let usb = probe.usbPresent()
        let lid = probe.lidOpen(snapshot: snap)
        snapshot = snap
        usbPresent = usb
        lidOpen = lid
        refreshNatural(quiet: true)

        let state = DockStateEvaluator.evaluate(snapshot: snap, usbPresent: usb, lidOpen: lid, settings: settings)
        let previous = dockState
        dockState = state

        var updated = settings
        let outcome = policy.decide(state: state, force: force, settings: &updated, now: now())
        if updated != settings {
            if updated.pause == .none { log.add(.info, "Pause ended") }
            setSettingsWithoutReacting(updated)
        }

        let summary = "\(state.label): \(snap.externals.count) external display\(snap.externals.count == 1 ? "" : "s"), lid \(lid ? "open" : "closed")"
        switch outcome {
        case .paused:
            if previous != state { log.add(.info, "\(summary). Paused, leaving Natural scrolling \(onOff(isNatural)) [\(reason)]") }
        case .unchanged:
            break
        case .apply(let state, let natural):
            apply(natural: natural, for: state, summary: summary, reason: reason)
        }
    }

    private func apply(natural: Bool, for state: DockState, summary: String, reason: String) {
        if toggler.isNatural == natural {
            isNatural = natural
            applyFailed = false
            log.add(.info, "\(summary). Natural scrolling already \(onOff(natural)) [\(reason)]")
            return
        }
        if toggler.setNatural(natural) {
            didSwitch(natural: natural, state: state, summary: summary, reason: reason)
            return
        }
        log.add(.warning, "\(summary). Setting Natural scrolling \(onOff(natural)) did not stick, retrying")
        DispatchQueue.main.asyncAfter(deadline: .now() + timing.retry) { [weak self] in
            guard let self else { return }
            if self.toggler.setNatural(natural) {
                self.didSwitch(natural: natural, state: state, summary: summary, reason: reason)
            } else {
                self.applyFailed = true
                self.refreshNatural(quiet: true)
                self.log.add(.error, "Could not set Natural scrolling \(self.onOff(natural)) (method: \(self.toggler.methodName))")
            }
        }
    }

    private func didSwitch(natural: Bool, state: DockState, summary: String, reason: String) {
        isNatural = natural
        applyFailed = false
        stats.record(now())
        store.set(stats.switches, for: Self.statsKey)
        log.add(.change, "\(summary). Natural scrolling → \(onOff(natural)) [\(reason)]")
        if settings.notificationsEnabled { notifier?.post("\(state.label): Natural scrolling \(onOff(natural))") }
    }

    // MARK: User actions

    /// One-time manual flip. Automation resumes on the next plug or unplug.
    public func flipNow() {
        let target = !toggler.isNatural
        if toggler.setNatural(target) {
            isNatural = target
            applyFailed = false
            log.add(.change, "Manual: Natural scrolling → \(onOff(target))")
        } else {
            applyFailed = true
            log.add(.error, "Manual flip to \(onOff(target)) did not stick")
        }
    }

    public func pause(for interval: TimeInterval) {
        settings.pause = .until(now().addingTimeInterval(interval))
        log.add(.info, "Paused until \(Self.timeFormatter.string(from: now().addingTimeInterval(interval)))")
    }

    public func pauseUntilNextChange() {
        let state = dockState ?? currentState()
        settings.pause = .untilNextChange(from: state)
        log.add(.info, "Paused until the next \(state == .docked ? "unplug" : "plug-in")")
    }

    public func pauseIndefinitely() {
        settings.pause = .indefinitely
        log.add(.info, "Paused indefinitely")
    }

    /// Resume automatic switching and apply the right value right away.
    public func resume() {
        settings.pause = .none
        log.add(.info, "Resumed automatic switching")
        evaluateAndApply(reason: "resumed", force: true)
    }

    /// Save the current external displays as the desk, keeping any saved USB devices.
    public func saveCurrentDesk() {
        let snap = probe.snapshot()
        snapshot = snap
        settings.desk.displays = snap.externals
        let names = snap.externals.map(\.name).joined(separator: ", ")
        log.add(.info, snap.externals.isEmpty ? "Saved desk with no displays" : "Saved desk: \(names)")
    }

    public func setUSBDevice(_ device: USBDeviceID, inDesk: Bool) {
        settings.desk.usbDevices.removeAll { $0 == device }
        if inDesk { settings.desk.usbDevices.append(device) }
    }

    public func setNotifications(_ on: Bool) {
        guard on else { settings.notificationsEnabled = false; return }
        if let notifier {
            notifier.requestPermission { [weak self] granted in
                self?.settings.notificationsEnabled = granted
                if !granted { self?.log.add(.warning, "Notifications were not allowed") }
            }
        } else {
            settings.notificationsEnabled = true
        }
    }

    public func refreshNow() {
        refreshNatural(quiet: false)
        snapshot = probe.snapshot()
        usbPresent = probe.usbPresent()
        lidOpen = probe.lidOpen(snapshot: snapshot)
    }

    // MARK: Internals

    private func currentState() -> DockState {
        let snap = probe.snapshot()
        return DockStateEvaluator.evaluate(snapshot: snap, usbPresent: probe.usbPresent(),
                                           lidOpen: probe.lidOpen(snapshot: snap), settings: settings)
    }

    private func tick() {
        refreshNatural(quiet: false)
        if case .until(let end) = settings.pause, end <= now() {
            evaluateAndApply(reason: "pause ended", force: true)
        }
    }

    private func refreshNatural(quiet: Bool) {
        let value = toggler.isNatural
        if value != isNatural {
            if !quiet { log.add(.info, "Natural scrolling changed outside ScrollSwitch → \(onOff(value))") }
            isNatural = value
        }
    }

    private var suppressReaction = false

    private func setSettingsWithoutReacting(_ value: SwitchSettings) {
        suppressReaction = true
        settings = value
        suppressReaction = false
    }

    private func settingsChanged(from old: SwitchSettings) {
        store.save(settings)
        guard !suppressReaction, started else { return }
        // Rules or preferred values changed: apply the new answer now.
        // Renaming the desk is not a decision input.
        let decisionInputsChanged = old.rule != settings.rule
            || old.desk.displays != settings.desk.displays || old.desk.usbDevices != settings.desk.usbDevices
            || old.lidOpenMeansUndocked != settings.lidOpenMeansUndocked
            || old.naturalWhenDocked != settings.naturalWhenDocked
            || old.naturalWhenUndocked != settings.naturalWhenUndocked
        if decisionInputsChanged {
            scheduleEvaluation(reason: "settings changed", delay: 0.3, force: true)
        }
    }

    private func onOff(_ on: Bool) -> String { on ? "ON" : "OFF" }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()
}
