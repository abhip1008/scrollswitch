import XCTest
@testable import ScrollSwitchCore

/// These never write the real setting. Resolving the symbol and reading the stored value
/// are both side-effect free, so they are safe to run on a development machine.
final class ScrollSetterTests: XCTestCase {
    func testReadingTheCurrentValueIsSafeAndTotal() {
        let setter = ScrollSetter()

        // Whatever the machine is set to, this must answer without trapping.
        XCTAssertTrue([ScrollDirection.natural, .traditional].contains(setter.current))
    }

    func testSupportAndDiagnosticsAgree() {
        let setter = ScrollSetter()

        if setter.isSupported {
            XCTAssertNil(setter.unsupportedReason)
            XCTAssertNotNil(setter.resolvedPath)
            XCTAssertNotNil(setter.resolvedSymbol)
        } else {
            // Milestone 0 failed on this macOS: the app must be able to explain why.
            XCTAssertNotNil(setter.unsupportedReason)
            XCTAssertNil(setter.resolvedSymbol)
        }
    }

    func testCandidatePathsAndSymbolsAreNotEmpty() {
        XCTAssertFalse(ScrollSetter.frameworkPaths.isEmpty)
        XCTAssertTrue(ScrollSetter.symbolNames.contains("setSwipeScrollDirection"))
    }

    func testTheNotificationNameMatchesTheOneSystemSettingsUses() {
        XCTAssertEqual(
            ScrollSetter.changedNotification.rawValue,
            "SwipeScrollDirectionDidChangeNotification"
        )
    }

    func testMemorySetterTracksWhatWasApplied() {
        let setter = MemoryScrollSetter(current: .natural)

        setter.apply(.traditional)
        setter.apply(.natural)

        XCTAssertEqual(setter.applied, [.traditional, .natural])
        XCTAssertEqual(setter.current, .natural)
        XCTAssertTrue(setter.didWeJustWrite())
    }

    func testDidWeJustWriteIsFalseForAnAgedWrite() {
        let setter = MemoryScrollSetter()
        setter.apply(.traditional)
        setter.pretendLastWriteWasLongAgo()

        XCTAssertFalse(setter.didWeJustWrite())
    }

    func testExternalChangesDoNotCountAsOurWrites() {
        let setter = MemoryScrollSetter(current: .natural)

        setter.setExternally(.traditional)

        XCTAssertEqual(setter.current, .traditional)
        XCTAssertTrue(setter.applied.isEmpty)
        XCTAssertFalse(setter.didWeJustWrite())
    }
}
