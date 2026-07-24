import AppKit
import Testing
@testable import {{PROJECT_NAME}}

@MainActor
@Suite("Root view controller")
struct RootViewControllerTests {
    @Test("loading the view builds its content in code")
    func viewLoads() {
        let controller = RootViewController()

        controller.loadViewIfNeeded()

        #expect(!controller.view.subviews.isEmpty)
    }
}
