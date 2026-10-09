import XCTest
@testable import ScrollSwitchCore

final class EventLogTests: XCTestCase {
    func testKeepsOnlyTheLastTwoHundredEvents() {
        let log = EventLog()

        for index in 1...250 {
            log.append(.state, "event \(index)")
        }

        XCTAssertEqual(log.events.count, EventLog.capacity)
        XCTAssertEqual(log.events.first?.message, "event 51")
        XCTAssertEqual(log.events.last?.message, "event 250")
    }

    func testTranscriptIsNewestFirst() {
        let log = EventLog()
        log.append(.app, "first")
        log.append(.app, "second")

        let lines = log.transcript.split(separator: "\n")

        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].hasSuffix("second"))
        XCTAssertTrue(lines[1].hasSuffix("first"))
    }

    func testClearEmptiesTheBuffer() {
        let log = EventLog()
        log.append(.app, "something")

        log.clear()

        XCTAssertTrue(log.events.isEmpty)
    }

    func testEveryCategoryHasASymbol() {
        for category in LogEvent.Category.allCases {
            XCTAssertFalse(category.symbol.isEmpty, "\(category.rawValue) needs an icon")
        }
    }
}
