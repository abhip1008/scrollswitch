import Foundation
import UserNotifications

/// Optional banner when ScrollSwitch switches. Only works inside the .app bundle.
public final class Notifier {
    public init() {}

    private var available: Bool { Bundle.main.bundleIdentifier != nil && Bundle.main.bundlePath.hasSuffix(".app") }

    /// Ask permission. Call only when the user turns notifications on.
    public func requestPermission(_ done: @escaping (Bool) -> Void) {
        guard available else { done(false); return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, _ in
            DispatchQueue.main.async { done(granted) }
        }
    }

    public func post(_ title: String) {
        guard available else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
