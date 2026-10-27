import Foundation

/// Counts automatic switches (just for fun). Keeps 30 days of timestamps.
public struct SwitchStats: Equatable, Sendable {
    public private(set) var switches: [Date]

    public init(switches: [Date] = []) {
        self.switches = switches
    }

    public mutating func record(_ date: Date) {
        switches.append(date)
        let cutoff = date.addingTimeInterval(-30 * 86_400)
        switches.removeAll { $0 < cutoff }
    }

    public func count(since date: Date) -> Int {
        switches.filter { $0 >= date }.count
    }

    public func countThisWeek(now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        return count(since: start)
    }
}
