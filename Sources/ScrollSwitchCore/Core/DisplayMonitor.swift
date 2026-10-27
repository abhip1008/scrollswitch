import AppKit
import CoreGraphics

/// Listens for display changes and builds snapshots of the online displays.
public final class DisplayMonitor {
    public var onChange: ((String) -> Void)?
    private var started = false
    private var observer: NSObjectProtocol?

    public init() {}

    public func start() {
        guard !started else { return }
        started = true
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        CGDisplayRegisterReconfigurationCallback(displayCallback, ctx)
        // Second signal. Both feed the same debounce, so duplicates do not matter.
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.onChange?("screen parameters changed") }
    }

    public func stop() {
        guard started else { return }
        started = false
        CGDisplayRemoveReconfigurationCallback(displayCallback, Unmanaged.passUnretained(self).toOpaque())
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    deinit { stop() }

    fileprivate func handle(display: CGDirectDisplayID, flags: CGDisplayChangeSummaryFlags) {
        var parts: [String] = []
        if flags.contains(.addFlag) { parts.append("added") }
        if flags.contains(.removeFlag) { parts.append("removed") }
        if flags.contains(.enabledFlag) { parts.append("enabled") }
        if flags.contains(.disabledFlag) { parts.append("disabled") }
        if flags.contains(.setModeFlag) { parts.append("mode changed") }
        let what = parts.isEmpty ? "changed" : parts.joined(separator: ", ")
        DispatchQueue.main.async { self.onChange?("display \(display) \(what)") }
    }

    public static func takeSnapshot() -> DisplaySnapshot {
        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetOnlineDisplayList(count, &ids, &count)

        let names = screenNames()
        let infos = ids.prefix(Int(count)).map { id in
            DisplayInfo(
                vendor: CGDisplayVendorNumber(id),
                model: CGDisplayModelNumber(id),
                serial: CGDisplaySerialNumber(id),
                isBuiltin: CGDisplayIsBuiltin(id) != 0,
                name: names[id] ?? (CGDisplayIsBuiltin(id) != 0 ? "Built-in Display" : "Display \(id)")
            )
        }
        return DisplaySnapshot(displays: infos)
    }

    private static func screenNames() -> [CGDirectDisplayID: String] {
        var result: [CGDirectDisplayID: String] = [:]
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        for screen in NSScreen.screens {
            if let number = screen.deviceDescription[key] as? NSNumber {
                result[number.uint32Value] = screen.localizedName
            }
        }
        return result
    }
}

private func displayCallback(display: CGDirectDisplayID, flags: CGDisplayChangeSummaryFlags, ctx: UnsafeMutableRawPointer?) {
    // Ignore the "about to change" call and only react after the change.
    guard !flags.contains(.beginConfigurationFlag), let ctx else { return }
    Unmanaged<DisplayMonitor>.fromOpaque(ctx).takeUnretainedValue().handle(display: display, flags: flags)
}
