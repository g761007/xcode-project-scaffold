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

    @Test("registering a tap advances the count")
    func registerTapAdvances() {
        let viewModel = GreetingViewModel(title: "Demo")

        viewModel.registerTap()

        #expect(viewModel.tapCount == 1)
        #expect(viewModel.tapCountText == "Tapped 1 time")
    }
}
