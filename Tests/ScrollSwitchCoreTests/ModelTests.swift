import XCTest
@testable import ScrollSwitchCore

final class ModelTests: XCTestCase {
    func testMatchRequiresVendorAndModel() {
        let a = DisplayInfo(vendor: 1, model: 2, serial: 3, isBuiltin: false, name: "A")
        XCTAssertTrue(a.matches(DisplayInfo(vendor: 1, model: 2, serial: 3, isBuiltin: false, name: "renamed")))
        XCTAssertFalse(a.matches(DisplayInfo(vendor: 1, model: 9, serial: 3, isBuiltin: false, name: "A")))
        XCTAssertFalse(a.matches(DisplayInfo(vendor: 9, model: 2, serial: 3, isBuiltin: false, name: "A")))
    }

    func testSerialOnlyComparedWhenBothNonZero() {
        let a = DisplayInfo(vendor: 1, model: 2, serial: 3, isBuiltin: false, name: "A")
        XCTAssertFalse(a.matches(DisplayInfo(vendor: 1, model: 2, serial: 4, isBuiltin: false, name: "A")))
        XCTAssertTrue(a.matches(DisplayInfo(vendor: 1, model: 2, serial: 0, isBuiltin: false, name: "A")))
        let zero = DisplayInfo(vendor: 1, model: 2, serial: 0, isBuiltin: false, name: "A")
        XCTAssertTrue(zero.matches(a))
    }

    func testSnapshotSplitsBuiltinAndExternals() {
        let snap = Fixture.snap(Fixture.builtin, Fixture.lg)
        XCTAssertTrue(snap.builtinOnline)
        XCTAssertEqual(snap.externals, [Fixture.lg])
        XCTAssertFalse(Fixture.snap(Fixture.lg).builtinOnline)
    }

    func testSettingsDefaults() {
        let s = SwitchSettings()
        XCTAssertEqual(s.rule, .anyExternal)
        XCTAssertFalse(s.naturalWhenDocked)
        XCTAssertTrue(s.naturalWhenUndocked)
        XCTAssertFalse(s.notificationsEnabled)
        XCTAssertFalse(s.lidOpenMeansUndocked)
        XCTAssertEqual(s.pause, .none)
        XCTAssertFalse(s.natural(for: .docked))
        XCTAssertTrue(s.natural(for: .undocked))
    }

    func testSettingsRoundTripThroughStore() {
        let suite = "scrollswitch.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SettingsStore(defaults: defaults)

        var s = Fixture.settings(.deskOrUSB)
        s.naturalWhenDocked = true
        s.lidOpenMeansUndocked = true
        s.pause = .untilNextChange(from: .docked)
        store.save(s)
        XCTAssertEqual(SettingsStore(defaults: defaults).load(), s)

        s.pause = .until(Date(timeIntervalSince1970: 1_000_000))
        store.save(s)
        XCTAssertEqual(store.load().pause, s.pause)
    }

    func testPartialSettingsBlobKeepsDefaults() throws {
        let json = #"{"rule":"usbDevice","naturalWhenDocked":true,"rule_typo":1}"#
        let s = try JSONDecoder().decode(SwitchSettings.self, from: Data(json.utf8))
        XCTAssertEqual(s.rule, .usbDevice)
        XCTAssertTrue(s.naturalWhenDocked)
        XCTAssertTrue(s.naturalWhenUndocked)
        XCTAssertEqual(s.pause, .none)
    }

    func testPauseResolution() {
        let now = Date()
        XCTAssertEqual(PauseState.until(now.addingTimeInterval(-1)).resolved(now: now), .none)
        XCTAssertTrue(PauseState.until(now.addingTimeInterval(60)).isActive(now: now))
        XCTAssertTrue(PauseState.indefinitely.isActive(now: now))
        XCTAssertTrue(PauseState.untilNextChange(from: .docked).isActive(now: now))
        XCTAssertFalse(PauseState.none.isActive(now: now))
    }

    func testStatsCountsThisWeekAndPrunes() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_793_000_000)
        var stats = SwitchStats()
        stats.record(now.addingTimeInterval(-40 * 86_400))
        stats.record(now.addingTimeInterval(-10 * 86_400))
        stats.record(now.addingTimeInterval(-60))
        stats.record(now)
        XCTAssertEqual(stats.switches.count, 3, "entries older than 30 days are pruned")
        XCTAssertEqual(stats.countThisWeek(now: now, calendar: cal), 2)
    }
}
