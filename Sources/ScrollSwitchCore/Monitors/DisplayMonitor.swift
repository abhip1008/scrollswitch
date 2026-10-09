import AppKit
import CoreGraphics
import Foundation

/// One attached display, identified well enough to recognise it again after a reboot.
public struct DisplayInfo: Hashable, Sendable, Identifiable {
    public let displayID: CGDirectDisplayID
    public let isBuiltin: Bool
    public let vendor: UInt32
    public let model: UInt32
    public let serial: UInt32
    public let name: String

    public init(
        displayID: CGDirectDisplayID,
        isBuiltin: Bool,
        vendor: UInt32,
        model: UInt32,
        serial: UInt32,
        name: String
    ) {
        self.displayID = displayID
        self.isBuiltin = isBuiltin
        self.vendor = vendor
        self.model = model
        self.serial = serial
        self.name = name
    }

    public var id: CGDirectDisplayID { displayID }

    public var identity: DisplayID {
        DisplayID(vendor: vendor, model: model, serial: serial)
    }
}

/// Watches displays appear and disappear via the CoreGraphics reconfiguration callback.
///
/// In clamshell mode the built-in display drops out of the online list entirely. That is
/// expected, which is why docking is decided on external displays only.
public final class DisplayMonitor {
    public var onChange: (([DisplayInfo]) -> Void)?

    private var running = false

    public init() {}

    public func start() {
        guard !running else { return }
        let result = CGDisplayRegisterReconfigurationCallback(
            displayReconfigurationCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        running = (result == .success)
    }

    public func stop() {
        guard running else { return }
        CGDisplayRemoveReconfigurationCallback(
            displayReconfigurationCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        running = false
    }

    deinit { stop() }

    /// Every online display, built-in included.
    public func snapshot() -> [DisplayInfo] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return [] }

        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return [] }

        let names = Self.screenNames()
        return ids.prefix(Int(count)).map { id in
            DisplayInfo(
                displayID: id,
                isBuiltin: CGDisplayIsBuiltin(id) != 0,
                vendor: CGDisplayVendorNumber(id),
                model: CGDisplayModelNumber(id),
                serial: CGDisplaySerialNumber(id),
                name: names[id] ?? "Display \(id)"
            )
        }
    }

    public func externalDisplays() -> [DisplayInfo] {
        snapshot().filter { !$0.isBuiltin }
    }

    fileprivate func handleReconfiguration() {
        onChange?(snapshot())
    }

    /// CoreGraphics knows the numbers; only NSScreen knows the marketing name.
    private static func screenNames() -> [CGDirectDisplayID: String] {
        var map: [CGDirectDisplayID: String] = [:]
        for screen in NSScreen.screens {
            let key = NSDeviceDescriptionKey("NSScreenNumber")
            guard let number = screen.deviceDescription[key] as? NSNumber else { continue }
            map[CGDirectDisplayID(number.uint32Value)] = screen.localizedName
        }
        return map
    }
}

/// C callback, so it cannot capture anything; the monitor arrives through userInfo.
private func displayReconfigurationCallback(
    _ display: CGDirectDisplayID,
    _ flags: CGDisplayChangeSummaryFlags,
    _ userInfo: UnsafeMutableRawPointer?
) {
    guard let userInfo else { return }

    // The begin pass fires before anything has actually moved, with stale geometry.
    guard !flags.contains(.beginConfigurationFlag) else { return }

    let interesting: CGDisplayChangeSummaryFlags = [
        .addFlag, .removeFlag, .enabledFlag, .disabledFlag, .desktopShapeChangedFlag,
    ]
    guard !flags.intersection(interesting).isEmpty else { return }

    let monitor = Unmanaged<DisplayMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    DispatchQueue.main.async { monitor.handleReconfiguration() }
}
