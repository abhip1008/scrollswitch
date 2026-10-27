import XCTest
@testable import ScrollSwitchCore

final class SwitchPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testFirstDecisionApplies() {
        var p = SwitchPolicy()
        var s = SwitchSettings()
        XCTAssertEqual(p.decide(state: .docked, force: false, settings: &s, now: now), .apply(.docked, natural: false))
        XCTAssertEqual(p.lastAppliedState, .docked)
    }

    func testSameStateIsLeftAlone() {
        var p = SwitchPolicy(lastAppliedState: .docked)
        var s = SwitchSettings()
        XCTAssertEqual(p.decide(state: .docked, force: false, settings: &s, now: now), .unchanged(.docked))
    }

    func testChangeApplies() {
        var p = SwitchPolicy(lastAppliedState: .docked)
        var s = SwitchSettings()
        XCTAssertEqual(p.decide(state: .undocked, force: false, settings: &s, now: now), .apply(.undocked, natural: true))
    }

    func testForceAppliesSameState() {
        var p = SwitchPolicy(lastAppliedState: .docked)
        var s = SwitchSettings()
        XCTAssertEqual(p.decide(state: .docked, force: true, settings: &s, now: now), .apply(.docked, natural: false))
    }

    func testPreferredValuesAreUsed() {
        var p = SwitchPolicy()
        var s = SwitchSettings()
        s.naturalWhenDocked = true
        s.naturalWhenUndocked = false
        XCTAssertEqual(p.decide(state: .docked, force: false, settings: &s, now: now), .apply(.docked, natural: true))
        XCTAssertEqual(p.decide(state: .undocked, force: false, settings: &s, now: now), .apply(.undocked, natural: false))
    }

    func testIndefinitePauseBlocksEvenForcedApplies() {
        var p = SwitchPolicy(lastAppliedState: .docked)
        var s = SwitchSettings()
        s.pause = .indefinitely
        XCTAssertEqual(p.decide(state: .undocked, force: false, settings: &s, now: now), .paused(.undocked))
        XCTAssertEqual(p.decide(state: .undocked, force: true, settings: &s, now: now), .paused(.undocked))
        XCTAssertEqual(s.pause, .indefinitely)
    }

    func testTimedPauseBlocksThenResumesWithForce() {
        var p = SwitchPolicy(lastAppliedState: .docked)
        var s = SwitchSettings()
        s.pause = .until(now.addingTimeInterval(3600))
        XCTAssertEqual(p.decide(state: .undocked, force: false, settings: &s, now: now), .paused(.undocked))
        XCTAssertEqual(p.lastAppliedState, .docked)

        // After the hour: pause clears and the current state is applied.
        let later = now.addingTimeInterval(3601)
        XCTAssertEqual(p.decide(state: .undocked, force: false, settings: &s, now: later), .apply(.undocked, natural: true))
        XCTAssertEqual(s.pause, .none)
    }

    func testTimedPauseEndingForcesEvenIfStateUnchanged() {
        var p = SwitchPolicy(lastAppliedState: .docked)
        var s = SwitchSettings()
        s.pause = .until(now.addingTimeInterval(-1))
        XCTAssertEqual(p.decide(state: .docked, force: false, settings: &s, now: now), .apply(.docked, natural: false))
    }

    func testPauseUntilNextChange() {
        var p = SwitchPolicy(lastAppliedState: .docked)
        var s = SwitchSettings()
        s.pause = .untilNextChange(from: .docked)
        // Wake while still docked: stays paused, even when forced.
        XCTAssertEqual(p.decide(state: .docked, force: true, settings: &s, now: now), .paused(.docked))
        // Unplug: pause ends and that change is applied.
        XCTAssertEqual(p.decide(state: .undocked, force: false, settings: &s, now: now), .apply(.undocked, natural: true))
        XCTAssertEqual(s.pause, .none)
    }
}
