import Foundation
import IOKit

/// One pointing device, as seen in the IORegistry.
public struct MouseInfo: Hashable, Sendable, Identifiable {
    public let vendorID: Int
    public let productID: Int
    public let name: String
    public let transport: String
    public let isBuiltIn: Bool

    public init(vendorID: Int, productID: Int, name: String, transport: String, isBuiltIn: Bool) {
        self.vendorID = vendorID
        self.productID = productID
        self.name = name
        self.transport = transport
        self.isBuiltIn = isBuiltIn
    }

    public var id: String { "\(vendorID)-\(productID)-\(name)" }

    public var identity: MouseID {
        MouseID(vendorID: vendorID, productID: productID)
    }
}

/// Watches mice and other pointers appear and disappear, including anything behind the
/// KVM USB hub.
///
/// It only ever asks the IORegistry what exists -- it never calls IOHIDManagerOpen, so
/// macOS does not demand Input Monitoring permission.
public final class DeviceMonitor {
    public var onChange: (([MouseInfo]) -> Void)?

    // HID usage page 0x01 is Generic Desktop; usage 0x02 is Mouse, 0x01 is Pointer.
    private static let genericDesktopPage = 0x01
    private static let usagesToWatch = [0x02, 0x01]

    // Raw IORegistry key names, so this file needs no IOKit.hid constants.
    private static let hidDeviceClass = "IOHIDDevice"
    private static let usagePageKey = "PrimaryUsagePage"
    private static let usageKey = "PrimaryUsage"

    private let queue = DispatchQueue(label: "com.abhirampurohit.ScrollSwitch.devices")
    private var port: IONotificationPortRef?
    private var iterators: [io_iterator_t] = []

    public init() {}

    public func start() {
        guard port == nil else { return }
        guard let notificationPort = IONotificationPortCreate(kIOMainPortDefault) else { return }
        IONotificationPortSetDispatchQueue(notificationPort, queue)
        port = notificationPort

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for usage in Self.usagesToWatch {
            for type in [kIOMatchedNotification, kIOTerminatedNotification] {
                guard let match = Self.matchingDictionary(usage: usage) else { continue }
                var iterator: io_iterator_t = 0
                let result = IOServiceAddMatchingNotification(
                    notificationPort,
                    type,
                    match,
                    deviceNotificationCallback,
                    refcon,
                    &iterator
                )
                guard result == KERN_SUCCESS else { continue }
                // Draining arms the notification; without this it never fires.
                drain(iterator)
                iterators.append(iterator)
            }
        }
    }

    public func stop() {
        for iterator in iterators { IOObjectRelease(iterator) }
        iterators.removeAll()
        if let port { IONotificationPortDestroy(port) }
        port = nil
    }

    deinit { stop() }

    /// Every pointing device currently attached, built-in trackpad included.
    public func snapshot() -> [MouseInfo] {
        var found: [MouseInfo] = []
        for usage in Self.usagesToWatch {
            guard let match = Self.matchingDictionary(usage: usage) else { continue }
            var iterator: io_iterator_t = 0
            guard IOServiceGetMatchingServices(kIOMainPortDefault, match, &iterator) == KERN_SUCCESS
            else { continue }
            var service = IOIteratorNext(iterator)
            while service != 0 {
                if let info = Self.describe(service) { found.append(info) }
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
        }
        // A device can advertise both Mouse and Pointer usage, so it shows up twice.
        var seen = Set<String>()
        return found.filter { seen.insert($0.id).inserted }
    }

    public func externalMice() -> [MouseInfo] {
        snapshot().filter { !$0.isBuiltIn }
    }

    fileprivate func handleNotification(_ iterator: io_iterator_t) {
        drain(iterator)
        let mice = snapshot()
        DispatchQueue.main.async { [weak self] in self?.onChange?(mice) }
    }

    private func drain(_ iterator: io_iterator_t) {
        var service = IOIteratorNext(iterator)
        while service != 0 {
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
    }

    private static func matchingDictionary(usage: Int) -> CFMutableDictionary? {
        guard let dictionary = IOServiceMatching(hidDeviceClass) else { return nil }
        let mutable = dictionary as NSMutableDictionary
        mutable[usagePageKey] = genericDesktopPage
        mutable[usageKey] = usage
        return dictionary
    }

    private static func describe(_ service: io_service_t) -> MouseInfo? {
        func property(_ key: String) -> Any? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue()
        }

        let vendor = (property("VendorID") as? NSNumber)?.intValue ?? 0
        let product = (property("ProductID") as? NSNumber)?.intValue ?? 0
        let name = (property("Product") as? String) ?? "Unnamed pointing device"
        let transport = (property("Transport") as? String) ?? "unknown"

        // Built-In is missing on some devices, so fall back to the transport: the
        // internal trackpad talks over SPI or the old-style FIFO bus, never USB or BT.
        let flagged = (property("Built-In") as? NSNumber)?.boolValue
        let internalBus = ["SPI", "FIFO"].contains(transport)
        let isBuiltIn = flagged ?? internalBus

        return MouseInfo(
            vendorID: vendor,
            productID: product,
            name: name,
            transport: transport,
            isBuiltIn: isBuiltIn
        )
    }
}

/// C callback: the monitor arrives through refcon.
private func deviceNotificationCallback(
    _ refcon: UnsafeMutableRawPointer?,
    _ iterator: io_iterator_t
) {
    guard let refcon else { return }
    let monitor = Unmanaged<DeviceMonitor>.fromOpaque(refcon).takeUnretainedValue()
    monitor.handleNotification(iterator)
}
