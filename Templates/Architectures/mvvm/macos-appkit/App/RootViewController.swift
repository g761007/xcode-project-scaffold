import AppKit

final class RootViewController: NSViewController {
    private let viewModel: GreetingViewModel
    private let titleLabel = NSTextField(labelWithString: "")
    private let tapCountLabel = NSTextField(labelWithString: "")
    private lazy var tapButton = NSButton(title: "Tap me", target: self, action: #selector(handleTap))

    /// The view model is created outside the view but defaulted here, so the app
    /// gets a working screen and a test can still supply its own. See
    /// App/GreetingViewModel.swift for the logic itself.
    init(viewModel: GreetingViewModel = GreetingViewModel(title: "{{PROJECT_NAME}}")) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used; this view is created in code.")
    }

    /// No storyboard or XIB: the view hierarchy is built in code (ADR-0006).
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 300))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        titleLabel.stringValue = viewModel.title
        titleLabel.font = .systemFont(ofSize: 36, weight: .semibold)

        let stack = NSStackView(views: [titleLabel, tapCountLabel, tapButton])
        stack.orientation = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        // Re-render whenever the view model changes, and once for the first state.
        viewModel.onChange = { [weak self] in self?.render() }
        render()
    }

    @objc private func handleTap() {
        viewModel.registerTap()
    }

    private func render() {
        tapCountLabel.stringValue = viewModel.tapCountText
    }
}
