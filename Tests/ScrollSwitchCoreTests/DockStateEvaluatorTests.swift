import XCTest
@testable import ScrollSwitchCore

final class DockStateEvaluatorTests: XCTestCase {
    private typealias F = Fixture

    private func eval(_ snap: DisplaySnapshot, usb: Set<USBDeviceID> = [], lidOpen: Bool = false,
                      _ settings: SwitchSettings) -> DockState {
        DockStateEvaluator.evaluate(snapshot: snap, usbPresent: usb, lidOpen: lidOpen, settings: settings)
    }

    // MARK: anyExternal

    func testAnyExternalDockedWithOneOrTwoExternals() {
        let s = F.settings(.anyExternal)
        XCTAssertEqual(eval(F.snap(F.lg), s), .docked)
        XCTAssertEqual(eval(F.snap(F.lg, F.acer), s), .docked)
        XCTAssertEqual(eval(F.snap(F.projector), lidOpen: true, s), .docked)
    }

    func testAnyExternalUndockedWithBuiltinOnly() {
        XCTAssertEqual(eval(F.snap(F.builtin), lidOpen: true, F.settings(.anyExternal)), .undocked)
    }

    func testNoDisplaysAtAllIsUndocked() {
        XCTAssertEqual(eval(F.snap(), F.settings(.anyExternal)), .undocked)
    }

    func testAnyExternalIgnoresDeskAndUSB() {
        let s = F.settings(.anyExternal, desk: [], usb: [])
        XCTAssertEqual(eval(F.snap(F.projector), s), .docked)
        XCTAssertEqual(eval(F.snap(F.builtin), usb: [F.kvmHub], lidOpen: true, s), .undocked)
    }

    // MARK: anyDeskDisplay

    func testAnyDeskDisplayMatchesSavedMonitor() {
        let s = F.settings(.anyDeskDisplay)
        XCTAssertEqual(eval(F.snap(F.lg), s), .docked)
        XCTAssertEqual(eval(F.snap(F.acer), s), .docked, "KVM switched away: HDMI monitor alone still counts")
    }

    func testAnyDeskDisplayIgnoresProjector() {
        XCTAssertEqual(eval(F.snap(F.builtin, F.projector), lidOpen: true, F.settings(.anyDeskDisplay)), .undocked)
    }

    func testAnyDeskDisplayWithEmptyDeskNeverDocks() {
        XCTAssertEqual(eval(F.snap(F.lg, F.acer), F.settings(.anyDeskDisplay, desk: [])), .undocked)
    }

    // MARK: allDeskDisplays

    func testAllDeskDisplaysNeedsEverySavedMonitor() {
        let s = F.settings(.allDeskDisplays)
        XCTAssertEqual(eval(F.snap(F.lg, F.acer), s), .docked)
        XCTAssertEqual(eval(F.snap(F.lg), s), .undocked)
        XCTAssertEqual(eval(F.snap(F.lg, F.projector), s), .undocked)
    }

    func testAllDeskDisplaysWithEmptyDeskNeverDocks() {
        XCTAssertEqual(eval(F.snap(F.lg), F.settings(.allDeskDisplays, desk: [])), .undocked)
    }

    func testAllDeskDisplaysToleratesExtraMonitor() {
        XCTAssertEqual(eval(F.snap(F.lg, F.acer, F.projector), F.settings(.allDeskDisplays)), .docked)
    }

    // MARK: usbDevice

    func testUSBDeviceRule() {
        let s = F.settings(.usbDevice)
        XCTAssertEqual(eval(F.snap(F.builtin), usb: [F.kvmHub], lidOpen: true, s), .docked, "KVM without monitors")
        XCTAssertEqual(eval(F.snap(F.lg, F.acer), usb: [F.thumbDrive], s), .undocked)
        XCTAssertEqual(eval(F.snap(F.lg, F.acer), usb: [], s), .undocked)
    }

    func testUSBMatchIgnoresName() {
        let renamed = USBDeviceID(vendorID: F.kvmHub.vendorID, productID: F.kvmHub.productID, name: "Something else")
        XCTAssertEqual(eval(F.snap(), usb: [renamed], F.settings(.usbDevice)), .docked)
    }

    // MARK: deskOrUSB

    func testDeskOrUSB() {
        let s = F.settings(.deskOrUSB)
        XCTAssertEqual(eval(F.snap(F.lg), s), .docked)
        XCTAssertEqual(eval(F.snap(F.builtin), usb: [F.kvmHub], lidOpen: true, s), .docked)
        XCTAssertEqual(eval(F.snap(F.builtin, F.projector), usb: [F.thumbDrive], lidOpen: true, s), .undocked)
    }

    // MARK: Lid option

    func testLidOpenTreatedAsDockedByDefault() {
        XCTAssertEqual(eval(F.snap(F.builtin, F.lg), lidOpen: true, F.settings(.anyExternal)), .docked)
    }

    func testLidOpenMeansUndockedOption() {
        var s = F.settings(.anyExternal)
        s.lidOpenMeansUndocked = true
        XCTAssertEqual(eval(F.snap(F.builtin, F.lg), lidOpen: true, s), .undocked)
        XCTAssertEqual(eval(F.snap(F.lg), lidOpen: false, s), .docked, "lid closed is still docked")
    }

    func testLidOptionAppliesToEveryRule() {
        for rule in TriggerRule.allCases {
            var s = F.settings(rule)
            s.lidOpenMeansUndocked = true
            XCTAssertEqual(eval(F.snap(F.builtin, F.lg, F.acer), usb: [F.kvmHub], lidOpen: true, s), .undocked, "\(rule)")
            XCTAssertEqual(eval(F.snap(F.lg, F.acer), usb: [F.kvmHub], lidOpen: false, s), .docked, "\(rule)")
        }
    }
}
