/// The screen's state and behaviour, with no reference to UIKit.
///
/// Keeping the logic here — not in the view controller — is what makes the extra
/// type worthwhile: the view model can be tested on its own, without a running
/// view. See `Tests/GreetingViewModelTests.swift`.
@MainActor
final class GreetingViewModel {
    let title: String
    private(set) var tapCount = 0

    /// Called when the state changes, so the view knows to re-render. A plain
    /// closure keeps the view model free of any UI framework; a larger app might
    /// reach for Observation or Combine instead.
    var onChange: (() -> Void)?

    init(title: String) {
        self.title = title
    }

    var tapCountText: String {
        "Tapped \(tapCount) time\(tapCount == 1 ? "" : "s")"
    }

    func registerTap() {
        tapCount += 1
        onChange?()
    }
}
