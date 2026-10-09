import Foundation

/// Notices when something other than ScrollSwitch changes the setting.
///
/// System Settings announces the change on the distributed notification centre, which is
/// also how it keeps its own checkbox in sync. FR-11 step 1.
public final class ScrollChangeWatcher {
    public var onChange: (() -> Void)?

    private var observer: NSObjectProtocol?

    public init() {}

    public func start() {
        guard observer == nil else { return }
        observer = DistributedNotificationCenter.default().addObserver(
            forName: ScrollSetter.changedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onChange?()
        }
    }

    public func stop() {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        observer = nil
    }

    deinit { stop() }
}
