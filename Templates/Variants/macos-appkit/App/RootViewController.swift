import AppKit

final class RootViewController: NSViewController {
    /// No storyboard or XIB: the view hierarchy is built in code (ADR-0006).
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 300))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let greeting = NSTextField(labelWithString: "{{PROJECT_NAME}}")
        greeting.font = .systemFont(ofSize: 36, weight: .semibold)
        greeting.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(greeting)

        NSLayoutConstraint.activate([
            greeting.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            greeting.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
