import Observation

/// The screen's state and behaviour, with no reference to SwiftUI.
///
/// `@Observable` lets the view read these properties and re-render when they
/// change, so the view holds no logic and the view model can be tested on its
/// own — see `Tests/GreetingViewModelTests.swift`.
@MainActor
@Observable
final class GreetingViewModel {
    let title: String
    private(set) var tapCount = 0

    init(title: String) {
        self.title = title
    }

    var tapCountText: String {
        "Tapped \(tapCount) time\(tapCount == 1 ? "" : "s")"
    }

    func registerTap() {
        tapCount += 1
    }
}
