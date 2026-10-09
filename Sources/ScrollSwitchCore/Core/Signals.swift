import Foundation

public enum DockState: String, Sendable, Equatable, CaseIterable {
    case docked
    case undocked

    public var displayName: String {
        self == .docked ? "Docked" : "Undocked"
    }
}

/// The combined state of every signal at one moment.
public struct SignalSnapshot: Equatable, Sendable {
    public var externalDisplays: [DisplayInfo]
    public var externalMice: [MouseInfo]
    /// nil means unknown, which happens on a desktop Mac.
    public var lidClosed: Bool?

    public init(
        externalDisplays: [DisplayInfo] = [],
        externalMice: [MouseInfo] = [],
        lidClosed: Bool? = nil
    ) {
        self.externalDisplays = externalDisplays
        self.externalMice = externalMice
        self.lidClosed = lidClosed
    }

    public static let empty = SignalSnapshot()
}

/// Abstracted so tests can drive the debounce clock by hand instead of sleeping.
public protocol DebounceScheduler: AnyObject {
    func schedule(after seconds: TimeInterval, _ work: @escaping () -> Void)
    func cancel()
}

/// Production scheduler: one pending work item on the main queue, replaced on each call.
public final class MainQueueDebouncer: DebounceScheduler {
    private var pending: DispatchWorkItem?

    public init() {}

    public func schedule(after seconds: TimeInterval, _ work: @escaping () -> Void) {
        cancel()
        let item = DispatchWorkItem(block: work)
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    public func cancel() {
        pending?.cancel()
        pending = nil
    }
}

/// Test scheduler: nothing runs until fire() is called.
public final class ManualDebouncer: DebounceScheduler {
    public private(set) var scheduleCount = 0
    public private(set) var lastDelay: TimeInterval?

    private var work: (() -> Void)?

    public init() {}

    public var isPending: Bool { work != nil }

    public func schedule(after seconds: TimeInterval, _ work: @escaping () -> Void) {
        scheduleCount += 1
        lastDelay = seconds
        self.work = work
    }

    public func cancel() { work = nil }

    public func fire() {
        let pending = work
        work = nil
        pending?()
    }
}
