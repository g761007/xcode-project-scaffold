import Testing
import UIKit
@testable import {{PROJECT_NAME}}

@MainActor
@Suite("Root view controller")
struct RootViewControllerTests {
    @Test("loading the view gives it a background")
    func viewLoads() {
        let controller = RootViewController(viewModel: GreetingViewModel(title: "Demo"))

        controller.loadViewIfNeeded()

        #expect(controller.view.backgroundColor == .systemBackground)
    }
}
