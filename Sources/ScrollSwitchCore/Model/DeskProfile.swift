import Foundation

/// The saved monitors and USB devices that make up "my desk".
public struct DeskProfile: Codable, Equatable, Sendable {
    public var name: String = "My Desk"
    public var displays: [DisplayInfo] = []
    public var usbDevices: [USBDeviceID] = []

    public init(name: String = "My Desk", displays: [DisplayInfo] = [], usbDevices: [USBDeviceID] = []) {
        self.name = name
        self.displays = displays
        self.usbDevices = usbDevices
    }

    public var isEmpty: Bool { displays.isEmpty && usbDevices.isEmpty }
}
