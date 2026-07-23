import UIKit

final class RootViewController: UIViewController {
    private let greeting = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        greeting.text = "{{PROJECT_NAME}}"
        greeting.font = .preferredFont(forTextStyle: .largeTitle)
        greeting.adjustsFontForContentSizeCategory = true
        greeting.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(greeting)

        NSLayoutConstraint.activate([
            greeting.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            greeting.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
