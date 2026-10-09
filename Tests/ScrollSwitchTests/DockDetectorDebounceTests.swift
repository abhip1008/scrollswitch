import XCTest
@testable import ScrollSwitchCore

/// Spec section 13.1: a burst of 5 add/remove events inside one second must produce
/// exactly one transition.
final class DockDetectorDebounceTests: XCTestCase {
    private var clock: ManualDebouncer!
    private var detector: DockDetector!
    private var transitions: [DockState] = []
    private var settleWithoutChangeCount = 0

    override func setUp() {
        super.setUp()
        clock = ManualDebouncer()
        var settings = Settings()
        settings.rule = .anyExternalDisplay
        settings.debounceSeconds = 1.5
        detector = DockDetector(settings: settings, scheduler: clock)
        transitions = []
        settleWithoutChangeCount = 0
        detector.onTransition = { [weak self] state, _ in self?.transitions.append(state) }
        detector.onSettleWithoutChange = { [weak self] _, _ in
            self?.settleWithoutChangeCount += 1
        }
    }

    private var docked: SignalSnapshot {
        SignalSnapshot(externalDisplays: [makeDisplay()])
    }

    private var undocked: SignalSnapshot { .empty }

    func testFirstEvaluationSettlesImmediately() {
        detector.submit(docked)

        XCTAssertFalse(clock.isPending, "The first evaluation must not wait for a window")
        XCTAssertEqual(transitions, [.docked])
        XCTAssertEqual(detector.state, .docked)
    }

    func testBurstOfEventsCollapsesIntoOneTransition() {
        detector.submit(undocked)
        transitions = []

        // A KVM switching over: devices come and go five times in a burst.
        detector.submit(docked)
        detector.submit(undocked)
        detector.submit(docked)
        detector.submit(undocked)
        detector.submit(docked)

        XCTAssertTrue(transitions.isEmpty, "Nothing may be applied while the window is open")
        XCTAssertTrue(detector.isPending)

        clock.fire()

        XCTAssertEqual(transitions, [.docked], "Exactly one transition for the whole burst")
        XCTAssertFalse(detector.isPending)
    }

    func testWindowThatSettlesBackWhereItStartedAppliesNothing() {
        detector.submit(docked)
        transitions = []

        // KVM switched to the other computer and straight back.
        detector.submit(undocked)
        detector.submit(docked)
        clock.fire()

        XCTAssertTrue(transitions.isEmpty)
        XCTAssertEqual(settleWithoutChangeCount, 1)
        XCTAssertEqual(detector.state, .docked)
    }

    func testEachSubmitRestartsTheWindow() {
        detector.submit(docked)
        detector.submit(undocked)
        detector.submit(undocked)
        detector.submit(undocked)

        XCTAssertEqual(clock.scheduleCount, 3, "One schedule per submit after the first")
    }

    func testDebounceDelayComesFromSettings() {
        var settings = Settings()
        settings.debounceSeconds = 3.0
        detector.updateSettings(settings)

        detector.submit(docked)
        detector.submit(undocked)

        XCTAssertEqual(clock.lastDelay, 3.0)
    }

    func testReevaluateSkipsTheWindow() {
        detector.submit(undocked)
        transitions = []

        detector.reevaluate(docked)

        XCTAssertEqual(transitions, [.docked])
        XCTAssertFalse(clock.isPending)
    }

    func testReevaluateCancelsAPendingWindow() {
        detector.submit(undocked)
        detector.submit(docked)
        XCTAssertTrue(clock.isPending)

        detector.reevaluate(undocked)

        XCTAssertFalse(clock.isPending)
        XCTAssertEqual(detector.state, .undocked)
    }

    func testResetMakesTheNextSubmitAFirstEvaluationAgain() {
        detector.submit(docked)
        detector.reset()
        XCTAssertNil(detector.state)

        transitions = []
        detector.submit(docked)

        XCTAssertEqual(transitions, [.docked])
        XCTAssertFalse(clock.isPending)
    }
}
