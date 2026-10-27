import XCTest
@testable import ScrollSwitchCore

@MainActor
final class ControllerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!

    override func setUp() async throws {
        suite = "scrollswitch.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
    }

    private func make(natural: Bool, probe: FakeProbe, settings: SwitchSettings = SwitchSettings())
        -> (Controller, FakeToggler) {
        let toggler = FakeToggler(natural)
        let store = SettingsStore(defaults: defaults)
        store.save(settings)
        var timing = Controller.Timing()
        timing.settle = 0.05
        timing.wake = 0.15
        timing.launchRecheck = 0.1
        timing.retry = 0.05
        timing.tick = 60
        return (Controller(toggler: toggler, probe: probe, store: store, timing: timing), toggler)
    }

    private func wait(_ seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    func testLaunchAppliesDocked() {
        let probe = FakeProbe(Fixture.snap(Fixture.lg, Fixture.acer), lidOpen: false)
        let (c, t) = make(natural: true, probe: probe)
        c.start()
        defer { c.stop() }
        XCTAssertEqual(c.dockState, .docked)
        XCTAssertEqual(t.writes, [false])
        XCTAssertFalse(c.isNatural)
        XCTAssertEqual(c.externalCount, 2)
    }

    func testAlreadyCorrectValueIsNotWritten() {
        let probe = FakeProbe(Fixture.snap(Fixture.builtin), lidOpen: true)
        let (c, t) = make(natural: true, probe: probe)
        c.start()
        defer { c.stop() }
        XCTAssertEqual(c.dockState, .undocked)
        XCTAssertEqual(t.writes, [])
    }

    func testBurstOfEventsCausesOneFlip() async {
        let probe = FakeProbe(Fixture.snap(Fixture.builtin), lidOpen: true)
        let (c, t) = make(natural: true, probe: probe)
        c.start()
        defer { c.stop() }
        await wait(0.15) // let the launch recheck pass

        // KVM flicker: several events, the state ends docked.
        for i in 0..<5 {
            if i.isMultiple(of: 2) { probe.dock() } else { probe.undock() }
            c.scheduleEvaluation(reason: "event \(i)")
            await wait(0.01)
        }
        XCTAssertTrue(c.hasPendingEvaluation)
        XCTAssertEqual(t.writes, [], "nothing happens until things settle")
        await wait(0.2)
        XCTAssertEqual(t.writes, [false])
        XCTAssertEqual(c.dockState, .docked)
    }

    func testManualChangeIsNotUndoneUntilNextChange() async {
        let probe = FakeProbe(Fixture.snap(Fixture.lg, Fixture.acer), lidOpen: false)
        let (c, t) = make(natural: true, probe: probe)
        c.start()
        defer { c.stop() }
        await wait(0.15)
        XCTAssertFalse(t.value)

        // The user turns Natural back on while docked, outside the app.
        t.value = true
        c.scheduleEvaluation(reason: "monitor slept and woke")
        await wait(0.1)
        XCTAssertTrue(t.value, "a display event without a state change leaves the user's choice")

        // Manual flip from the menu is also left alone.
        c.flipNow()
        XCTAssertFalse(t.value)
        c.flipNow()
        XCTAssertTrue(t.value)
        c.scheduleEvaluation(reason: "noise")
        await wait(0.1)
        XCTAssertTrue(t.value)

        // Next real change applies again.
        probe.undock()
        c.scheduleEvaluation(reason: "unplugged")
        await wait(0.1)
        XCTAssertTrue(t.value)
        probe.dock()
        c.scheduleEvaluation(reason: "plugged")
        await wait(0.1)
        XCTAssertFalse(t.value)
    }

    func testWakeForcesReapply() async {
        let probe = FakeProbe(Fixture.snap(Fixture.lg), lidOpen: false)
        let (c, t) = make(natural: false, probe: probe)
        c.start()
        defer { c.stop() }
        await wait(0.15)
        t.value = true // changed by hand before sleeping
        c.scheduleEvaluation(reason: "woke from sleep", delay: 0.05, force: true)
        await wait(0.1)
        XCTAssertFalse(t.value, "wake always applies, even if the state looks the same")
    }

    func testWakeKeepsForceAndLongerDelayWhenDisplayEventArrives() async {
        let probe = FakeProbe(Fixture.snap(Fixture.lg), lidOpen: false)
        let (c, t) = make(natural: false, probe: probe)
        c.start()
        defer { c.stop() }
        await wait(0.15)
        t.value = true
        c.scheduleEvaluation(reason: "woke from sleep", delay: 0.3, force: true)
        c.scheduleEvaluation(reason: "display added") // shorter settle must not cut the wake wait
        await wait(0.12)
        XCTAssertTrue(t.value, "still waiting for the wake settle")
        await wait(0.3)
        XCTAssertFalse(t.value, "force flag survived the later non-forced event")
    }

    func testUnpluggedWhileAsleepGivesNaturalOnAfterWake() async {
        let probe = FakeProbe(Fixture.snap(Fixture.lg, Fixture.acer), lidOpen: false)
        let (c, t) = make(natural: true, probe: probe)
        c.start()
        defer { c.stop() }
        await wait(0.15)
        XCTAssertFalse(t.value)
        probe.undock() // happened while asleep, no display events seen
        c.scheduleEvaluation(reason: "woke from sleep", delay: 0.05, force: true)
        await wait(0.1)
        XCTAssertTrue(t.value)
        XCTAssertEqual(c.dockState, .undocked)
    }

    func testPausedIgnoresUnplugAndResumeApplies() async {
        let probe = FakeProbe(Fixture.snap(Fixture.lg), lidOpen: false)
        let (c, t) = make(natural: true, probe: probe)
        c.start()
        defer { c.stop() }
        await wait(0.15)
        XCTAssertFalse(t.value)

        c.pause(for: 3600)
        XCTAssertTrue(c.isPaused)
        probe.undock()
        c.scheduleEvaluation(reason: "unplugged")
        await wait(0.1)
        XCTAssertFalse(t.value, "paused: no change")

        c.resume()
        XCTAssertFalse(c.isPaused)
        XCTAssertTrue(t.value, "resume applies the current state right away")
    }

    func testPauseIndefinitelySurvivesRestart() {
        let probe = FakeProbe(Fixture.snap(Fixture.lg), lidOpen: false)
        let (c, _) = make(natural: true, probe: probe)
        c.pauseIndefinitely()
        let reloaded = SettingsStore(defaults: defaults).load()
        XCTAssertEqual(reloaded.pause, .indefinitely)

        let toggler = FakeToggler(true)
        let c2 = Controller(toggler: toggler, probe: probe, store: SettingsStore(defaults: defaults))
        c2.start()
        defer { c2.stop() }
        XCTAssertEqual(toggler.writes, [], "paused at launch: nothing changes")
        _ = c
    }

    func testPauseUntilNextChange() async {
        let probe = FakeProbe(Fixture.snap(Fixture.lg), lidOpen: false)
        let (c, t) = make(natural: true, probe: probe)
        c.start()
        defer { c.stop() }
        await wait(0.15)
        t.value = true
        c.pauseUntilNextChange()
        c.scheduleEvaluation(reason: "woke", delay: 0.02, force: true)
        await wait(0.08)
        XCTAssertTrue(t.value, "still docked: stays paused")
        probe.undock()
        c.scheduleEvaluation(reason: "unplugged")
        await wait(0.1)
        XCTAssertFalse(c.isPaused)
        XCTAssertTrue(t.value)
        probe.dock()
        c.scheduleEvaluation(reason: "plugged")
        await wait(0.1)
        XCTAssertFalse(t.value, "automation is back")
    }

    func testDeskRuleIgnoresProjector() {
        var s = SwitchSettings()
        s.rule = .anyDeskDisplay
        s.desk.displays = [Fixture.lg, Fixture.acer]
        let probe = FakeProbe(Fixture.snap(Fixture.builtin, Fixture.projector), lidOpen: true)
        let (c, t) = make(natural: true, probe: probe, settings: s)
        c.start()
        defer { c.stop() }
        XCTAssertEqual(c.dockState, .undocked)
        XCTAssertTrue(t.value)
        XCTAssertEqual(t.writes, [])
    }

    func testSaveCurrentDeskStoresExternalsOnly() {
        let probe = FakeProbe(Fixture.snap(Fixture.lg, Fixture.acer), lidOpen: false)
        let (c, _) = make(natural: false, probe: probe)
        probe.displays = Fixture.snap(Fixture.builtin, Fixture.lg, Fixture.acer)
        c.saveCurrentDesk()
        XCTAssertEqual(c.settings.desk.displays.map(\.name), ["LG ULTRAGEAR", "XV272U W2"])
        XCTAssertEqual(SettingsStore(defaults: defaults).load().desk.displays.count, 2)
    }

    func testChangingPreferredValueReapplies() async {
        let probe = FakeProbe(Fixture.snap(Fixture.lg), lidOpen: false)
        let (c, t) = make(natural: true, probe: probe)
        c.start()
        defer { c.stop() }
        await wait(0.15)
        XCTAssertFalse(t.value)
        c.settings.naturalWhenDocked = true
        await wait(0.5)
        XCTAssertTrue(t.value)
    }

    func testStuckSetRetriesThenFlagsFailure() async {
        let probe = FakeProbe(Fixture.snap(Fixture.lg), lidOpen: false)
        let (c, t) = make(natural: true, probe: probe)
        t.stuck = true
        c.start()
        defer { c.stop() }
        XCTAssertFalse(c.applyFailed)
        await wait(0.15)
        XCTAssertEqual(t.writes.count, 2, "one try plus one retry")
        XCTAssertTrue(c.applyFailed)
        XCTAssertEqual(c.log.events.first?.kind, .error)
    }

    func testSwitchesAreCounted() async {
        let probe = FakeProbe(Fixture.snap(Fixture.builtin), lidOpen: true)
        let (c, _) = make(natural: true, probe: probe)
        c.start()
        defer { c.stop() }
        await wait(0.15)
        probe.dock()
        c.scheduleEvaluation(reason: "plugged")
        await wait(0.1)
        probe.undock()
        c.scheduleEvaluation(reason: "unplugged")
        await wait(0.1)
        XCTAssertEqual(c.stats.switches.count, 2)
    }

    func testEventLogKeepsLast100() {
        let log = EventLog()
        for i in 0..<150 { log.add(.info, "event \(i)") }
        XCTAssertEqual(log.events.count, 100)
        XCTAssertEqual(log.latest?.message, "event 149")
    }
}
