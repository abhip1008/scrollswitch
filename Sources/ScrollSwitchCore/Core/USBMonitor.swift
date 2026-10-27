import Foundation
import IOKit
import IOKit.usb

/// Watches USB devices with IOKit matching notifications. Does not open HID devices, so no
/// Input Monitoring permission is needed.
public final class USBMonitor {
    public var onChange: ((String) -> Void)?
    public private(set) var present: Set<USBDeviceID> = []

    private var port: IONotificationPortRef?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0

    public init() {}

    public func start() {
        guard port == nil else { return }
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        self.port = port
        CFRunLoopAddSource(CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(port).takeUnretainedValue(), .defaultMode)

        let ctx = Unmanaged.passUnretained(self).toOpaque()
        IOServiceAddMatchingNotification(port, kIOFirstMatchNotification, IOServiceMatching("IOUSBHostDevice"),
                                         usbCallback, ctx, &addedIterator)
        IOServiceAddMatchingNotification(port, kIOTerminatedNotification, IOServiceMatching("IOUSBHostDevice"),
                                         usbCallback, ctx, &removedIterator)
        // Drain both iterators to arm the notifications.
        drain(addedIterator)
        drain(removedIterator)
        present = Self.scan()
    }

    public func stop() {
        if addedIterator != 0 { IOObjectRelease(addedIterator); addedIterator = 0 }
        if removedIterator != 0 { IOObjectRelease(removedIterator); removedIterator = 0 }
        if let port { IONotificationPortDestroy(port) }
        port = nil
    }

    deinit { stop() }

    fileprivate func handle(iterator: io_iterator_t) {
        drain(iterator)
        let now = Self.scan()
        let added = now.subtracting(present)
        let removed = present.subtracting(now)
        present = now
        guard !added.isEmpty || !removed.isEmpty else { return }
        var parts: [String] = []
        if !added.isEmpty { parts.append("USB added: " + added.map(\.name).sorted().joined(separator: ", ")) }
        if !removed.isEmpty { parts.append("USB removed: " + removed.map(\.name).sorted().joined(separator: ", ")) }
        onChange?(parts.joined(separator: "; "))
    }

    private func drain(_ iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            IOObjectRelease(service)
        }
    }

    /// Every USB device currently attached.
    public static func scan() -> Set<USBDeviceID> {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOUSBHostDevice"), &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }
        var result: Set<USBDeviceID> = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            guard let vendor = property(service, "idVendor") as? Int,
                  let product = property(service, "idProduct") as? Int else { continue }
            let name = (property(service, "USB Product Name") as? String)
                ?? (property(service, kUSBProductString) as? String)
                ?? String(format: "USB %04X:%04X", vendor, product)
            result.insert(USBDeviceID(vendorID: vendor, productID: product, name: name))
        }
        return result
    }

    private static func property(_ service: io_service_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}

private func usbCallback(ctx: UnsafeMutableRawPointer?, iterator: io_iterator_t) {
    guard let ctx else { return }
    Unmanaged<USBMonitor>.fromOpaque(ctx).takeUnretainedValue().handle(iterator: iterator)
}
