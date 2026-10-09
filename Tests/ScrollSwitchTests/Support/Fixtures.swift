import Foundation
@testable import ScrollSwitchCore

// Stand-in hardware. Defaults describe the setup in the spec: a Dell U2723QE on the KVM
// and a plain USB optical mouse.

func makeDisplay(
    id: UInt32 = 1,
    vendor: UInt32 = 0x10AC,
    model: UInt32 = 0x41B2,
    serial: UInt32 = 1,
    builtin: Bool = false,
    name: String = "DELL U2723QE"
) -> DisplayInfo {
    DisplayInfo(
        displayID: id,
        isBuiltin: builtin,
        vendor: vendor,
        model: model,
        serial: serial,
        name: name
    )
}

func makeMouse(
    vendorID: Int = 0x046D,
    productID: Int = 0xC52B,
    name: String = "USB Optical Mouse",
    transport: String = "USB",
    builtIn: Bool = false
) -> MouseInfo {
    MouseInfo(
        vendorID: vendorID,
        productID: productID,
        name: name,
        transport: transport,
        isBuiltIn: builtIn
    )
}

let builtInTrackpad = makeMouse(
    vendorID: 0x05AC,
    productID: 0x0341,
    name: "Apple Internal Keyboard / Trackpad",
    transport: "SPI",
    builtIn: true
)
