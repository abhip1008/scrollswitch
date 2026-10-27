import Foundation
import os

public struct LogEvent: Identifiable, Equatable, Sendable {
    public enum Kind: String, Sendable { case info, change, warning, error }

    public let id = UUID()
    public let date: Date
    public let kind: Kind
    public let message: String

    public init(date: Date = Date(), kind: Kind, message: String) {
        self.date = date
        self.kind = kind
        self.message = message
    }
}

/// Writes to the unified system log and keeps the last 100 events for "Recent activity".
///
///     log stream --predicate 'subsystem == "com.abhirampurohit.scrollswitch"'
@MainActor
public final class EventLog: ObservableObject {
    public static let subsystem = "com.abhirampurohit.scrollswitch"
    public static let capacity = 100

    @Published public private(set) var events: [LogEvent] = []
    /// Extra sink, used by the command-line tool to print every event.
    public var echo: ((LogEvent) -> Void)?

    private let logger = Logger(subsystem: EventLog.subsystem, category: "engine")

    public init() {}

    public func add(_ kind: LogEvent.Kind, _ message: String) {
        let event = LogEvent(kind: kind, message: message)
        switch kind {
        case .info: logger.info("\(message, privacy: .public)")
        case .change: logger.notice("\(message, privacy: .public)")
        case .warning: logger.warning("\(message, privacy: .public)")
        case .error: logger.error("\(message, privacy: .public)")
        }
        events.insert(event, at: 0)
        if events.count > Self.capacity { events.removeLast(events.count - Self.capacity) }
        echo?(event)
    }

    public var latest: LogEvent? { events.first }

    public func clear() { events.removeAll() }
}
