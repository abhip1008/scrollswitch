import Foundation

/// One connected display, as reported by CoreGraphics.
public struct DisplayInfo: Codable, Hashable, Sendable {
    public let vendor: UInt32
    public let model: UInt32
    public let serial: UInt32
    public let isBuiltin: Bool
    public var name: String

    public init(vendor: UInt32, model: UInt32, serial: UInt32, isBuiltin: Bool, name: String) {
        self.vendor = vendor
        self.model = model
        self.serial = serial
        self.isBuiltin = isBuiltin
        self.name = name
    }

    /// Vendor and model must match. Serial must match only when both sides report one,
    /// since some monitors report a serial of 0.
    public func matches(_ other: DisplayInfo) -> Bool {
        guard vendor == other.vendor, model == other.model else { return false }
        if serial != 0 && other.serial != 0 { return serial == other.serial }
        return true
    }
}

/// Every online display at one moment.
public struct DisplaySnapshot: Equatable, Sendable {
    public let displays: [DisplayInfo]

    public init(displays: [DisplayInfo]) {
        self.displays = displays
    }

    public var externals: [DisplayInfo] { displays.filter { !$0.isBuiltin } }
    public var builtinOnline: Bool { displays.contains { $0.isBuiltin } }
}
