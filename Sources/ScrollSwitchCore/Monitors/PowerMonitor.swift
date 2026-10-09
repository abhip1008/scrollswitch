import AppKit
import Foundation

/// Sleep and wake, so the app can re-scan after the Mac comes back (FR-7).
///
/// Both didWake and screensDidWake are observed: monitors on a KVM sometimes only
/// reappear on the second one, a few seconds later.
public final class PowerMonitor {
    public var onWake: ((String) -> Void)?
    public var onSleep: (() -> Void)?

    private var observers: [NSObjectProtocol] = []

    public init() {}

    public func start() {
        guard observers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter

        func observeWake(_ name: Notification.Name, _ label: String) {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.onWake?(label)
            }
            observers.append(token)
        }

        observeWake(NSWorkspace.didWakeNotification, "system wake")
        observeWake(NSWorkspace.screensDidWakeNotification, "screens wake")

        let sleepToken = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onSleep?()
        }
        observers.append(sleepToken)
    }

    public func stop() {
        let center = NSWorkspace.shared.notificationCenter
        for observer in observers { center.removeObserver(observer) }
        observers.removeAll()
    }

    deinit { stop() }
}
