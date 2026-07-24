import XCTest

/// The first screen appears. Deliberately shallow: it asserts a window, not
/// its contents, so it survives every redesign and still catches a blank
/// launch. Deeper flows belong in tests written against them.
final class SmokeTests: XCTestCase {
    @MainActor
    func testFirstScreenAppears() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
    }
}
