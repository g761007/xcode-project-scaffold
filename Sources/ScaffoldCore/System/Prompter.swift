import Foundation

/// The one door to interactive input, so that a test can drive `new` through a
/// scripted set of answers without a real terminal — the same reason
/// `ProcessRunner` exists for the outside world.
///
/// Questions are shown to the person answering, never on stdout: stdout is
/// reserved for the result (§11.3), so a prompt going there would corrupt it for
/// a caller reading the created project's summary.
public protocol Prompter: Sendable {
    /// Whether input is a terminal a person can answer at. `new` refuses to run
    /// without one, so that a script does not silently hang waiting on stdin.
    var isInteractive: Bool { get }

    /// Shows a line to the person answering.
    func show(_ line: String)

    /// Reads one answer, or `nil` when input has ended — Ctrl-D at a terminal, or
    /// a closed pipe. `new` treats that as cancellation.
    func readLine() -> String?
}

/// Talks to the real terminal: questions to stderr, answers from stdin.
public struct SystemPrompter: Prompter {
    public init() {}

    public var isInteractive: Bool {
        isatty(FileHandle.standardInput.fileDescriptor) != 0
    }

    public func show(_ line: String) {
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }

    public func readLine() -> String? {
        Swift.readLine(strippingNewline: true)
    }
}
