import Foundation
@testable import ScaffoldCore

/// Records what a run would execute, and can be told that a tool is missing,
/// that a command fails, or what a command says — the three things every test
/// of the outside world needs to control.
final class FakeProcessRunner: ProcessRunner, @unchecked Sendable {
    /// What the command was, and what it could see when it ran.
    struct Execution: Sendable {
        var invocation: ProcessInvocation
        var visibleFiles: [String]
    }

    private let missing: Set<String>
    private let failing: String?
    private let output: [String: String]
    private let lock = NSLock()
    private var recorded: [Execution] = []

    init(missing: Set<String> = [], failing: String? = nil, output: [String: String] = [:]) {
        self.missing = missing
        self.failing = failing
        self.output = output
    }

    var executions: [Execution] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    var invocations: [ProcessInvocation] {
        executions.map(\.invocation)
    }

    func locate(_ executable: String) -> URL? {
        missing.contains(executable) ? nil : URL(fileURLWithPath: "/usr/bin/\(executable)")
    }

    func run(_ invocation: ProcessInvocation) throws -> ProcessResult {
        // Same contract as the real runner: a command that is not installed
        // fails before it runs, rather than reporting a non-zero status.
        guard !missing.contains(invocation.executable) else {
            throw GenerationError.executableNotFound(invocation.executable)
        }

        let visible = (try? FileManager.default.contentsOfDirectory(
            atPath: invocation.workingDirectory.path
        )) ?? []

        lock.lock()
        recorded.append(Execution(invocation: invocation, visibleFiles: visible.sorted()))
        lock.unlock()

        guard invocation.executable == failing else {
            return ProcessResult(exitStatus: 0, standardOutput: output[invocation.executable] ?? "")
        }

        // Both streams, as real tools use them: some put the explanation on
        // stdout and only a summary on stderr.
        return ProcessResult(
            exitStatus: 2,
            standardOutput: "error: line 1 is wrong\n",
            standardError: "fatal: it did not work\n"
        )
    }
}
