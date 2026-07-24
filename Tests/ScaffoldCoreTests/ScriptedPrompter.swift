@testable import ScaffoldCore

/// A `Prompter` that answers from a script and records what it was shown, so a
/// test can drive the interactive collection without a terminal — the same role
/// `FakeProcessRunner` plays for the outside world.
final class ScriptedPrompter: Prompter, @unchecked Sendable {
    let isInteractive: Bool
    private var answers: [String]
    private(set) var shown: [String] = []

    init(_ answers: [String], isInteractive: Bool = true) {
        self.answers = answers
        self.isInteractive = isInteractive
    }

    func show(_ line: String) {
        shown.append(line)
    }

    func readLine() -> String? {
        answers.isEmpty ? nil : answers.removeFirst()
    }

    /// How many shown lines begin with a label — a question asked once, or the
    /// same one asked again after a validation failure.
    func timesAsked(_ label: String) -> Int {
        shown.filter { $0.hasPrefix(label) }.count
    }

    /// Where a question first appears, for asserting the order they came in.
    func firstIndex(of label: String) -> Int? {
        shown.firstIndex { $0.hasPrefix(label) }
    }
}
