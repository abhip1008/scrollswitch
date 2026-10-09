import Foundation
import os

/// One line in the rolling event log shown by Show Log (FR-13).
public struct LogEvent: Identifiable, Sendable, Equatable {
    public enum Category: String, Sendable, CaseIterable {
        case app
        case display
        case device
        case lid
        case power
        case state
        case direction
        case error

        public var symbol: String {
            switch self {
            case .app: return "app.badge"
            case .display: return "display"
            case .device: return "computermouse"
            case .lid: return "laptopcomputer"
            case .power: return "bolt"
            case .state: return "arrow.triangle.2.circlepath"
            case .direction: return "arrow.up.arrow.down"
            case .error: return "exclamationmark.triangle"
            }
        }
    }

    public let id: UUID
    public let date: Date
    public let category: Category
    public let message: String

    public init(id: UUID = UUID(), date: Date = Date(), category: Category, message: String) {
        self.id = id
        self.date = date
        self.category = category
        self.message = message
    }

    public var formatted: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return "\(f.string(from: date))  [\(category.rawValue)]  \(message)"
    }
}

/// Ring buffer of the last 200 events, plus a mirror into the unified log so events
/// survive a crash and can be read with `log show --predicate`.
public final class EventLog: ObservableObject {
    public static let capacity = 200

    @Published public private(set) var events: [LogEvent] = []

    private let logger = os.Logger(subsystem: "com.abhirampurohit.ScrollSwitch", category: "events")

    public init() {}

    public func append(_ category: LogEvent.Category, _ message: String) {
        let event = LogEvent(category: category, message: message)
        switch category {
        case .error:
            logger.error("[\(category.rawValue, privacy: .public)] \(message, privacy: .public)")
        default:
            logger.log("[\(category.rawValue, privacy: .public)] \(message, privacy: .public)")
        }
        if Thread.isMainThread {
            insert(event)
        } else {
            DispatchQueue.main.async { [weak self] in self?.insert(event) }
        }
    }

    public func clear() {
        if Thread.isMainThread {
            events.removeAll()
        } else {
            DispatchQueue.main.async { [weak self] in self?.events.removeAll() }
        }
    }

    /// Newest first, ready to paste into a bug report.
    public var transcript: String {
        events.reversed().map(\.formatted).joined(separator: "\n")
    }

    private func insert(_ event: LogEvent) {
        events.append(event)
        if events.count > Self.capacity {
            events.removeFirst(events.count - Self.capacity)
        }
    }
}
