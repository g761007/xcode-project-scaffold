import Testing
@testable import {{PROJECT_NAME}}

@MainActor
@Suite("Greeting view model")
struct GreetingViewModelTests {
    @Test("it starts with no taps")
    func startsWithNoTaps() {
        let viewModel = GreetingViewModel(title: "Demo")

        #expect(viewModel.tapCount == 0)
        #expect(viewModel.tapCountText == "Tapped 0 times")
    }

    @Test("registering a tap advances the count and notifies the view")
    func registerTapNotifies() {
        let viewModel = GreetingViewModel(title: "Demo")
        var changes = 0
        viewModel.onChange = { changes += 1 }

        viewModel.registerTap()

        #expect(viewModel.tapCount == 1)
        #expect(viewModel.tapCountText == "Tapped 1 time")
        #expect(changes == 1)
    }
}
