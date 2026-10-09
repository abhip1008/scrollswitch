import XCTest
@testable import ScrollSwitchCore

/// Holds the settings the controller reads, so a test can change the configuration
/// mid-scenario the way the Preferences window would.
private final class SettingsBox {
    var value = Settings()
}

final class ScrollControllerTests: XCTestCase {
    private var setter: MemoryScrollSetter!
    private var log: EventLog!
    private var box: SettingsBox!
    private var controller: ScrollController!

    override func setUp() {
        super.setUp()
        setter = MemoryScrollSetter(current: .natural)
        log = EventLog()
        box = SettingsBox()
        let box = box!
        controller = ScrollController(setter: setter, log: log) { box.value }
    }

    func testDockingAppliesTheDockedDirection() {
        controller.handleTransition(to: .docked)

        XCTAssertEqual(setter.applied, [.traditional])
        XCTAssertEqual(setter.current, .traditional)
    }

    func testUndockingAppliesTheUndockedDirection() {
        setter.setExternally(.traditional)

        controller.handleTransition(to: .undocked)

        XCTAssertEqual(setter.applied, [.natural])
    }

    func testCustomDirectionsAreRespected() {
        box.value.dockedDirection = .natural
        box.value.undockedDirection = .traditional

        controller.handleTransition(to: .undocked)

        XCTAssertEqual(setter.applied, [.traditional])
    }

    /// Spec section 11: setting already correct means skip the apply call.
    func testAlreadyCorrectSkipsTheWrite() {
        controller.handleTransition(to: .undocked)

        XCTAssertTrue(setter.applied.isEmpty)
        XCTAssertEqual(controller.lastSkipReason, .alreadyCorrect)
    }

    func testPausedAutomationWritesNothing() {
        box.value.automationEnabled = false

        controller.handleTransition(to: .docked)

        XCTAssertTrue(setter.applied.isEmpty)
        XCTAssertEqual(controller.lastSkipReason, .paused)
    }

    func testForceAppliesEvenWhilePausedAndThenPinsTheDirection() {
        box.value.automationEnabled = false

        controller.force(.traditional)
        XCTAssertEqual(setter.applied, [.traditional])
        XCTAssertEqual(controller.forcedDirection, .traditional)

        // A dock change must not undo a forced direction.
        controller.handleTransition(to: .undocked)
        XCTAssertEqual(setter.applied, [.traditional])
        XCTAssertEqual(controller.lastSkipReason, .forced(.traditional))
    }

    func testFollowingTheDockStateAgainReappliesForThatState() {
        controller.force(.traditional)
        setter.reset()

        controller.resumeAutomatic(currentState: .undocked)

        XCTAssertNil(controller.forcedDirection)
        XCTAssertEqual(setter.applied, [.natural])
    }

    /// FR-11 steps 1 and 2.
    func testAChangeFromSystemSettingsSetsManualOverride() {
        setter.pretendLastWriteWasLongAgo()
        setter.setExternally(.traditional)

        controller.externalChangeDetected()

        XCTAssertTrue(controller.manualOverride)
        XCTAssertEqual(controller.lastSkipReason, .manualOverride)
    }

    /// Our own apply posts the same notification, so it must not look manual.
    func testOurOwnWriteIsNotMistakenForAManualChange() {
        controller.handleTransition(to: .docked)

        controller.externalChangeDetected()

        XCTAssertFalse(controller.manualOverride)
    }

    /// FR-11 step 3, and spec manual tests 7 and 8.
    func testOverrideSurvivesAWakeButExpiresOnTheNextDockChange() {
        controller.handleTransition(to: .docked)
        XCTAssertEqual(setter.current, .traditional)

        setter.pretendLastWriteWasLongAgo()
        setter.setExternally(.natural)
        controller.externalChangeDetected()
        setter.reset()

        // Waking up docked must leave the manual choice alone.
        controller.reconcile(with: .docked, trigger: "Wake")
        XCTAssertTrue(setter.applied.isEmpty)
        XCTAssertTrue(controller.manualOverride)

        // Undocking is a real transition, so the override expires.
        controller.handleTransition(to: .undocked)
        XCTAssertFalse(controller.manualOverride)

        // And the next dock change applies normally again.
        controller.handleTransition(to: .docked)
        XCTAssertEqual(setter.applied, [.traditional])
    }

    func testReconcileCorrectsDriftWhenThereIsNoOverride() {
        controller.handleTransition(to: .docked)
        setter.reset()
        setter.pretendLastWriteWasLongAgo()
        setter.setExternally(.natural)

        controller.reconcile(with: .docked, trigger: "Launch")

        XCTAssertEqual(setter.applied, [.traditional], "A fresh launch should correct the value")
    }

    func testAnUnsupportedMacOSNeverWrites() {
        let unsupported = MemoryScrollSetter(current: .natural, isSupported: false)
        let box = SettingsBox()
        let controller = ScrollController(setter: unsupported, log: EventLog()) { box.value }

        controller.handleTransition(to: .docked)

        XCTAssertTrue(unsupported.applied.isEmpty)
        XCTAssertEqual(controller.lastSkipReason, .unsupported)
    }
}
