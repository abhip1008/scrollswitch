import Foundation
@testable import ScrollSwitchCore

enum Fixture {
    static let builtin = DisplayInfo(vendor: 1552, model: 41_000, serial: 0, isBuiltin: true, name: "Built-in Retina Display")
    static let lg = DisplayInfo(vendor: 7789, model: 30_798, serial: 402_653_440, isBuiltin: false, name: "LG ULTRAGEAR")
    static let acer = DisplayInfo(vendor: 1138, model: 4664, serial: 16_843_009, isBuiltin: false, name: "XV272U W2")
    static let projector = DisplayInfo(vendor: 4268, model: 1, serial: 0, isBuiltin: false, name: "Classroom Projector")

    static let kvmHub = USBDeviceID(vendorID: 1507, productID: 1574, name: "USB3.1 Hub")
    static let mouse = USBDeviceID(vendorID: 1133, productID: 50_489, name: "USB Receiver")
    static let thumbDrive = USBDeviceID(vendorID: 2385, productID: 5734, name: "Thumb Drive")

    static func snap(_ displays: DisplayInfo...) -> DisplaySnapshot { DisplaySnapshot(displays: displays) }

    static func settings(_ rule: TriggerRule, desk: [DisplayInfo] = [lg, acer], usb: [USBDeviceID] = [kvmHub]) -> SwitchSettings {
        var s = SwitchSettings()
        s.rule = rule
        s.desk = DeskProfile(displays: desk, usbDevices: usb)
        return s
    }
}

final class FakeToggler: ScrollToggling {
    var value: Bool
    var writes: [Bool] = []
    /// When true, writes are ignored (simulates a set call that does not stick).
    var stuck = false
    let methodName = "fake"

    init(_ value: Bool) { self.value = value }

    var isNatural: Bool { value }
    func write(_ on: Bool) {
        writes.append(on)
        if !stuck { value = on }
    }
}

final class FakeProbe: SystemProbe {
    var displays: DisplaySnapshot
    var usb: Set<USBDeviceID> = []
    var lid: Bool

    init(_ displays: DisplaySnapshot, lidOpen: Bool) {
        self.displays = displays
        self.lid = lidOpen
    }

    func snapshot() -> DisplaySnapshot { displays }
    func usbPresent() -> Set<USBDeviceID> { usb }
    func lidOpen(snapshot: DisplaySnapshot) -> Bool { lid }

    func dock() { displays = Fixture.snap(Fixture.lg, Fixture.acer); lid = false }
    func undock() { displays = Fixture.snap(Fixture.builtin); lid = true }
}
