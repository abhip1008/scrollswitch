import AppKit

/// Reports sleep and wake so the controller can recheck after waking.
public final class PowerMonitor {
    public var onWake: ((String) -> Void)?
    public var onSleep: (() -> Void)?
    private var observers: [NSObjectProtocol] = []

    public init() {}

    public func start() {
        guard observers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.onWake?("woke from sleep")
        })
        observers.append(center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.onWake?("screens woke")
        })
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.onSleep?()
        })
    }

    public func stop() {
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach(center.removeObserver)
        observers.removeAll()
    }

    deinit { stop() }
}
