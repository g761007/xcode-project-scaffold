import UIKit

final class RootViewController: UIViewController {
    private let viewModel: GreetingViewModel
    private let titleLabel = UILabel()
    private let tapCountLabel = UILabel()
    private let tapButton = UIButton(configuration: .filled())

    init(viewModel: GreetingViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used; this view is created in code.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        titleLabel.text = viewModel.title
        titleLabel.font = .preferredFont(forTextStyle: .largeTitle)
        titleLabel.adjustsFontForContentSizeCategory = true

        tapCountLabel.font = .preferredFont(forTextStyle: .body)
        tapCountLabel.adjustsFontForContentSizeCategory = true

        tapButton.setTitle("Tap me", for: .normal)
        tapButton.addAction(
            UIAction { [weak self] _ in self?.viewModel.registerTap() },
            for: .touchUpInside
        )

        let stack = UIStackView(arrangedSubviews: [titleLabel, tapCountLabel, tapButton])
        stack.axis = .vertical
        stack.alignment = .center
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

    private func render() {
        tapCountLabel.text = viewModel.tapCountText
    }
}
