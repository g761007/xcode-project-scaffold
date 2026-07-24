import XCTest

/// How long launching takes, measured the way Xcode reports it. Optional
/// (testing.ui.launchPerformanceTest): a baseline is only useful to projects
/// that intend to watch it.
final class LaunchPerformanceTests: XCTestCase {
    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
