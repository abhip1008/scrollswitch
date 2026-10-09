import Foundation

/// Which way the content moves when you push the wheel or swipe up.
public enum ScrollDirection: String, Codable, Sendable, CaseIterable, Identifiable {
    case natural
    case traditional

    public var id: String { rawValue }

    public init(isNatural: Bool) {
        self = isNatural ? .natural : .traditional
    }

    public var isNatural: Bool { self == .natural }

    public var opposite: ScrollDirection { isNatural ? .traditional : .natural }

    public var displayName: String {
        switch self {
        case .natural: return "Natural"
        case .traditional: return "Traditional"
        }
    }
}

/// How DockDetector decides that the Mac is docked. See spec section 6.3.
public enum DockRule: String, Codable, Sendable, CaseIterable, Identifiable {
    case markers
    case anyExternalDisplay
    case anyExternalMouse

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .markers: return "Dock markers"
        case .anyExternalDisplay: return "Any external display"
        case .anyExternalMouse: return "Any external mouse"
        }
    }

    public var explanation: String {
        switch self {
        case .markers:
            return "Docked when a display or mouse you taught me is present. Ignores random monitors."
        case .anyExternalDisplay:
            return "Docked when at least one external display is connected."
        case .anyExternalMouse:
            return "Docked when at least one external mouse is connected."
        }
    }
}

/// Stable identity of a display, from the CoreGraphics vendor/model/serial triple.
public struct DisplayID: Hashable, Codable, Sendable, Identifiable {
    public let vendor: UInt32
    public let model: UInt32
    public let serial: UInt32

    public init(vendor: UInt32, model: UInt32, serial: UInt32) {
        self.vendor = vendor
        self.model = model
        self.serial = serial
    }

    public var id: String { "\(vendor)-\(model)-\(serial)" }
}

/// Stable identity of a pointing device, from its USB/BT vendor and product IDs.
public struct MouseID: Hashable, Codable, Sendable, Identifiable {
    public let vendorID: Int
    public let productID: Int

    public init(vendorID: Int, productID: Int) {
        self.vendorID = vendorID
        self.productID = productID
    }

    public var id: String { "\(vendorID)-\(productID)" }
}
