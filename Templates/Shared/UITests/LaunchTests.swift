import XCTest

/// The app starts. The cheapest possible answer to "did this build produce
/// something that runs?", and the first test to fail when it did not.
final class LaunchTests: XCTestCase {
    @MainActor
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertEqual(app.state, .runningForeground)
    }
}
