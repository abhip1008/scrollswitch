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
///
/// The IOKit notification is registered for every IOHIDDevice rather than a usage-filtered
/// subset, because a mouse does not reliably advertise itself in PrimaryUsage. Pointers are
/// picked out when the registry is read, and an event that leaves the pointer list
/// unchanged (a keyboard being plugged in, say) is swallowed rather than reported.
public final class DeviceMonitor {
    public var onChange: (([MouseInfo]) -> Void)?

    // HID usage page 0x01 is Generic Desktop; usage 0x02 is Mouse and 0x01 is Pointer.
    private static let hidDeviceClass = "IOHIDDevice"
    private static let genericDesktopPage = 1
    private static let pointerUsages: Set<Int> = [1, 2]

    private let queue = DispatchQueue(label: "com.abhirampurohit.ScrollSwitch.devices")
    private var port: IONotificationPortRef?
    private var iterators: [io_iterator_t] = []
    private var lastSeen: [MouseInfo]?

    public init() {}

    public func start() {
        guard port == nil else { return }
        guard let notificationPort = IONotificationPortCreate(kIOMainPortDefault) else { return }
        IONotificationPortSetDispatchQueue(notificationPort, queue)
        port = notificationPort

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for type in [kIOMatchedNotification, kIOTerminatedNotification] {
            var iterator: io_iterator_t = 0
            let result = IOServiceAddMatchingNotification(
                notificationPort,
                type,
                IOServiceMatching(Self.hidDeviceClass),
                deviceNotificationCallback,
                refcon,
                &iterator
            )
            guard result == KERN_SUCCESS else { continue }
            // Draining arms the notification; without this it never fires.
            drain(iterator)
            iterators.append(iterator)
        }

        lastSeen = snapshot()
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
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching(Self.hidDeviceClass),
            &iterator
        )
        guard result == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var found: [MouseInfo] = []
        var seen = Set<String>()
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let info = Self.describePointer(service), seen.insert(info.id).inserted {
                found.append(info)
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return found
    }

    public func externalMice() -> [MouseInfo] {
        snapshot().filter { mouse in !mouse.isBuiltIn }
    }

    fileprivate func handleNotification(_ iterator: io_iterator_t) {
        drain(iterator)
        let mice = snapshot()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.lastSeen != mice else { return }
            self.lastSeen = mice
            self.onChange?(mice)
        }
    }

    private func drain(_ iterator: io_iterator_t) {
        var service = IOIteratorNext(iterator)
        while service != 0 {
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
    }

    private static func describePointer(_ service: io_service_t) -> MouseInfo? {
        func property(_ key: String) -> Any? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue()
        }

        let isPointer = pointerUsageFound(
            primaryPage: property("PrimaryUsagePage") as? NSNumber,
            primaryUsage: property("PrimaryUsage") as? NSNumber,
            usagePairs: property("DeviceUsagePairs") as? [[String: Any]]
        )
        guard isPointer else { return nil }

        let vendor = (property("VendorID") as? NSNumber)?.intValue ?? 0
        let product = (property("ProductID") as? NSNumber)?.intValue ?? 0
        let name = (property("Product") as? String) ?? "Unnamed pointing device"
        let transport = (property("Transport") as? String) ?? "unknown"

        // Built-In is missing on some devices, so fall back to the transport: the
        // internal trackpad talks over SPI or the old FIFO bus, never USB or Bluetooth.
        let flagged = (property("Built-In") as? NSNumber)?.boolValue
        let internalBus = ["SPI", "FIFO"].contains(transport)

        return MouseInfo(
            vendorID: vendor,
            productID: product,
            name: name,
            transport: transport,
            isBuiltIn: flagged ?? internalBus
        )
    }

    /// Some mice only declare Mouse usage inside DeviceUsagePairs, so both places count.
    private static func pointerUsageFound(
        primaryPage: NSNumber?,
        primaryUsage: NSNumber?,
        usagePairs: [[String: Any]]?
    ) -> Bool {
        if primaryPage?.intValue == genericDesktopPage,
           let usage = primaryUsage?.intValue,
           pointerUsages.contains(usage) {
            return true
        }

        for pair in usagePairs ?? [] {
            let page = (pair["DeviceUsagePage"] as? NSNumber)?.intValue
            guard page == genericDesktopPage else { continue }
            if let usage = (pair["DeviceUsage"] as? NSNumber)?.intValue,
               pointerUsages.contains(usage) {
                return true
            }
        }

        return false
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
