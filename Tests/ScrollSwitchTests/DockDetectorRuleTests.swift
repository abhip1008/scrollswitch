import XCTest
@testable import ScrollSwitchCore

/// Spec section 13.1: feed sequences of display, mouse, and lid events for each rule and
/// check the transitions.
final class DockDetectorRuleTests: XCTestCase {
    func testAnyExternalDisplayRule() {
        var settings = Settings()
        settings.rule = .anyExternalDisplay

        let withDisplay = SignalSnapshot(externalDisplays: [makeDisplay()])
        XCTAssertTrue(DockDetector.isDocked(snapshot: withDisplay, settings: settings))

        let withMouseOnly = SignalSnapshot(externalMice: [makeMouse()])
        XCTAssertFalse(DockDetector.isDocked(snapshot: withMouseOnly, settings: settings))

        XCTAssertFalse(DockDetector.isDocked(snapshot: .empty, settings: settings))
    }

    func testAnyExternalMouseRule() {
        var settings = Settings()
        settings.rule = .anyExternalMouse

        let withMouse = SignalSnapshot(externalMice: [makeMouse()])
        XCTAssertTrue(DockDetector.isDocked(snapshot: withMouse, settings: settings))

        let withDisplayOnly = SignalSnapshot(externalDisplays: [makeDisplay()])
        XCTAssertFalse(DockDetector.isDocked(snapshot: withDisplayOnly, settings: settings))
    }

    func testMarkersRuleOnlyMatchesLearnedHardware() {
        let dockDisplay = makeDisplay(serial: 111)
        let classroomProjector = makeDisplay(id: 9, vendor: 0x04E8, model: 0x7777, serial: 999, name: "Epson PowerLite")

        var settings = Settings()
        settings.rule = .markers
        settings.markerDisplays = [dockDisplay.identity]

        XCTAssertTrue(
            DockDetector.isDocked(
                snapshot: SignalSnapshot(externalDisplays: [dockDisplay]),
                settings: settings
            )
        )
        XCTAssertFalse(
            DockDetector.isDocked(
                snapshot: SignalSnapshot(externalDisplays: [classroomProjector]),
                settings: settings
            ),
            "A random projector must not count as the dock"
        )
    }

    func testMarkersRuleMatchesALearnedMouseAlone() {
        let dockMouse = makeMouse()
        var settings = Settings()
        settings.rule = .markers
        settings.markerMice = [dockMouse.identity]

        let snapshot = SignalSnapshot(externalMice: [dockMouse])
        XCTAssertTrue(DockDetector.isDocked(snapshot: snapshot, settings: settings))
    }

    /// Markers with nothing learned would never be true, so it must degrade.
    func testEmptyMarkersFallBackToAnyExternalDisplay() {
        var settings = Settings()
        settings.rule = .markers

        XCTAssertEqual(DockDetector.effectiveRule(for: settings), .anyExternalDisplay)
        XCTAssertTrue(
            DockDetector.isDocked(
                snapshot: SignalSnapshot(externalDisplays: [makeDisplay()]),
                settings: settings
            )
        )
    }

    func testLidModifierOnlyEverMakesDockingHarder() {
        var settings = Settings()
        settings.rule = .anyExternalDisplay
        settings.requireLidClosed = true

        let displays = [makeDisplay()]

        XCTAssertTrue(
            DockDetector.isDocked(
                snapshot: SignalSnapshot(externalDisplays: displays, lidClosed: true),
                settings: settings
            )
        )
        XCTAssertFalse(
            DockDetector.isDocked(
                snapshot: SignalSnapshot(externalDisplays: displays, lidClosed: false),
                settings: settings
            )
        )
        XCTAssertFalse(
            DockDetector.isDocked(
                snapshot: SignalSnapshot(externalDisplays: displays, lidClosed: nil),
                settings: settings
            ),
            "Unknown lid state must not be treated as closed"
        )
    }

    func testBuiltInHardwareIsNeverADockSignal() {
        var settings = Settings()
        settings.rule = .anyExternalMouse

        // The coordinator filters built-ins out before building a snapshot, so an empty
        // external list is what the detector should see when only the trackpad is there.
        XCTAssertFalse(builtInTrackpad.isBuiltIn == false)
        XCTAssertFalse(DockDetector.isDocked(snapshot: .empty, settings: settings))
    }
}
