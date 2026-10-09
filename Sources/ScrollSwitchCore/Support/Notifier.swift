import Foundation
import UserNotifications

/// Optional banner when the direction changes (FR-14).
///
/// Guarded on a real bundle identifier, because UNUserNotificationCenter is unusable
/// from a bare command-line binary.
public final class Notifier {
    private var requestedAuthorization = false

    public init() {}

    public var isUsable: Bool { Bundle.main.bundleIdentifier != nil }

    public func requestAuthorizationIfNeeded() {
        guard isUsable, !requestedAuthorization else { return }
        requestedAuthorization = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    public func post(title: String, body: String) {
        guard isUsable else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
