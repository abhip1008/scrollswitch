import XCTest
@testable import ScrollSwitchCore

final class SettingsTests: XCTestCase {
    func testDefaultsMatchTheSpec() {
        let settings = Settings()

        XCTAssertTrue(settings.automationEnabled)
        XCTAssertEqual(settings.rule, .anyExternalDisplay)
        XCTAssertFalse(settings.requireLidClosed)
        XCTAssertEqual(settings.dockedDirection, .traditional)
        XCTAssertEqual(settings.undockedDirection, .natural)
        XCTAssertEqual(settings.debounceSeconds, 1.5)
        XCTAssertFalse(settings.notifyOnChange)
        XCTAssertTrue(settings.launchAtLogin)
    }

    func testDirectionForState() {
        var settings = Settings()
        settings.dockedDirection = .traditional
        settings.undockedDirection = .natural

        XCTAssertEqual(settings.direction(for: .docked), .traditional)
        XCTAssertEqual(settings.direction(for: .undocked), .natural)
    }

    func testRoundTrip() throws {
        var settings = Settings()
        settings.rule = .markers
        settings.markerDisplays = [DisplayID(vendor: 1, model: 2, serial: 3)]
        settings.markerMice = [MouseID(vendorID: 4, productID: 5)]
        settings.markerLabels = ["1-2-3": "DELL U2723QE"]
        settings.debounceSeconds = 2.5

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(Settings.self, from: data)

        XCTAssertEqual(decoded, settings)
    }

    /// A settings blob written by an older build must still load, with anything new
    /// sitting at its default instead of failing the whole decode.
    func testPartialJSONKeepsDefaults() throws {
        let json = Data("{\"rule\":\"anyExternalMouse\"}".utf8)

        let decoded = try JSONDecoder().decode(Settings.self, from: json)

        XCTAssertEqual(decoded.rule, .anyExternalMouse)
        XCTAssertEqual(decoded.debounceSeconds, 1.5)
        XCTAssertTrue(decoded.automationEnabled)
    }

    func testStoreSavesAndLoads() throws {
        let suite = "com.abhirampurohit.ScrollSwitch.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.load(), Settings(), "An empty domain must yield the defaults")

        var settings = Settings()
        settings.notifyOnChange = true
        settings.debounceSeconds = 4.0
        store.save(settings)

        XCTAssertEqual(store.load(), settings)

        store.reset()
        XCTAssertEqual(store.load(), Settings())
    }

    func testMarkerLabelFallsBackToTheIdentity() {
        let settings = Settings()
        let display = DisplayID(vendor: 7, model: 8, serial: 9)

        XCTAssertEqual(settings.label(for: display), "Display 7-8-9")
    }

    func testScrollDirectionHelpers() {
        XCTAssertEqual(ScrollDirection(isNatural: true), .natural)
        XCTAssertEqual(ScrollDirection(isNatural: false), .traditional)
        XCTAssertEqual(ScrollDirection.natural.opposite, .traditional)
        XCTAssertEqual(ScrollDirection.traditional.opposite, .natural)
    }
}
