import Foundation

/// A USB device identified by vendor and product ID. The name is for display only and is
/// not part of equality, so a renamed device still matches.
public struct USBDeviceID: Codable, Hashable, Sendable {
    public let vendorID: Int
    public let productID: Int
    public var name: String

    public init(vendorID: Int, productID: Int, name: String = "") {
        self.vendorID = vendorID
        self.productID = productID
        self.name = name
    }

    public static func == (lhs: USBDeviceID, rhs: USBDeviceID) -> Bool {
        lhs.vendorID == rhs.vendorID && lhs.productID == rhs.productID
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(vendorID)
        hasher.combine(productID)
    }

    public var hexDescription: String {
        String(format: "%04X:%04X", vendorID, productID)
    }
}
