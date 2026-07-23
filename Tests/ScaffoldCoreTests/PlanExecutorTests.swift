import Foundation
@testable import ScaffoldCore
import ScaffoldSchema
import Testing

// MARK: - Fixtures

/// Records what a run would execute, and can be told that a tool is missing or
/// that a command fails — the two failures that decide whether the destination
/// is left clean.
private final class FakeProcessRunner: ProcessRunner, @unchecked Sendable {
    /// What the command was, and what it could see when it ran.
    struct Execution: Sendable {
        var invocation: ProcessInvocation
        var visibleFiles: [String]
    }

    private let missing: Set<String>
    private let failing: String?
    private let lock = NSLock()
    private var recorded: [Execution] = []

    init(missing: Set<String> = [], failing: String? = nil) {
        self.missing = missing
        self.failing = failing
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
        let visible = (try? FileManager.default.contentsOfDirectory(
            atPath: invocation.workingDirectory.path
        )) ?? []

        lock.lock()
        recorded.append(Execution(invocation: invocation, visibleFiles: visible.sorted()))
        lock.unlock()

        guard invocation.executable == failing else { return ProcessResult(exitStatus: 0) }
        return ProcessResult(exitStatus: 2, standardError: "fatal: it did not work\n")
    }
}

private let samplePlan = GenerationPlan(
    files: [
        PlannedFile(path: "App/Main.swift", contents: "print(\"hello\")\n"),
        PlannedFile(path: "README.md", contents: "# Sample\n")
    ],
    commands: [
        PlannedCommand(executable: "git", arguments: ["init"], purpose: "Start a repository"),
        PlannedCommand(executable: "xcodegen", arguments: ["generate"], purpose: "Produce the project")
    ]
)

private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("xscaffold-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try body(root)
}

private func entries(of directory: URL) throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
}

private func contents(of file: URL) throws -> String {
    try String(contentsOf: file, encoding: .utf8)
}

// MARK: - Tests

@Suite("Writing a plan to disk")
struct PlanExecutorWriteTests {
    @Test("every planned file arrives, directories and all")
    func writesFiles() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("MyApp")
            try PlanExecutor(processRunner: FakeProcessRunner()).execute(samplePlan, at: destination)

            #expect(try contents(of: destination.appendingPathComponent("App/Main.swift")) == "print(\"hello\")\n")
            #expect(try contents(of: destination.appendingPathComponent("README.md")) == "# Sample\n")
        }
    }

    /// The staging area is an implementation detail of "never half-build in the
    /// destination" (§10). A leftover one is litter in the user's directory.
    ///
    /// Both routes out of staging are checked. Publishing into a destination
    /// that was not there moves the staging directory and so consumes it; every
    /// other route has to delete it, and only those can leave litter behind.
    @Test("the staging area does not survive the run", arguments: [false, true])
    func stagingIsRemoved(destinationExists: Bool) throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("MyApp")
            if destinationExists {
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
            }

            try PlanExecutor(processRunner: FakeProcessRunner()).execute(samplePlan, at: destination)

            #expect(try entries(of: root) == ["MyApp"])
        }
    }

    @Test("missing parent directories are created")
    func createsParents() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("one/two/MyApp")
            try PlanExecutor(processRunner: FakeProcessRunner()).execute(samplePlan, at: destination)

            #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("README.md").path))
        }
    }

    @Test("commands run in the destination, in the order planned")
    func runsCommands() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("MyApp")
            let runner = FakeProcessRunner()
            try PlanExecutor(processRunner: runner).execute(samplePlan, at: destination)

            #expect(runner.invocations.map(\.executable) == ["git", "xcodegen"])
            #expect(runner.invocations.allSatisfy { $0.workingDirectory == destination })
        }
    }

    /// Ordering that matters: every planned command reads a generated file —
    /// `git add .` and `xcodegen generate` both do — so none of them may run
    /// before the files are in place.
    @Test("nothing is executed until the files are in the destination")
    func filesArriveBeforeCommands() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("MyApp")
            let runner = FakeProcessRunner()
            try PlanExecutor(processRunner: runner).execute(samplePlan, at: destination)

            #expect(runner.executions.allSatisfy { $0.visibleFiles == ["App", "README.md"] })
        }
    }

    @Test("an existing but empty destination is written into")
    func emptyDestination() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("MyApp")
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)

            try PlanExecutor(processRunner: FakeProcessRunner()).execute(samplePlan, at: destination)

            #expect(try entries(of: destination) == ["App", "README.md"])
        }
    }
}

@Suite("Refusing to write")
struct PlanExecutorRefusalTests {
    @Test("a destination with anything in it is refused")
    func nonEmptyDestination() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("MyApp")
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
            try "mine".write(to: destination.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

            #expect(throws: GenerationError.destinationNotEmpty(destination)) {
                try PlanExecutor(processRunner: FakeProcessRunner()).execute(samplePlan, at: destination)
            }

            #expect(try entries(of: destination) == ["notes.txt"])
            #expect(try entries(of: root) == ["MyApp"])
        }
    }

    @Test("--force writes into it and leaves what it did not plan alone")
    func forcedDestination() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("MyApp")
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
            try "mine".write(to: destination.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)
            try "old".write(to: destination.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)

            try PlanExecutor(processRunner: FakeProcessRunner()).execute(samplePlan, at: destination, force: true)

            #expect(try entries(of: destination) == ["App", "README.md", "notes.txt"])
            #expect(try contents(of: destination.appendingPathComponent("README.md")) == "# Sample\n")
            #expect(try contents(of: destination.appendingPathComponent("notes.txt")) == "mine")
        }
    }

    /// `--force` replaces files. A directory standing where a planned file goes
    /// is refused rather than removed, because removing it would take
    /// everything under it and there is no way back from that.
    @Test("--force will not replace a directory with a file")
    func forcedOverADirectory() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("MyApp")
            let occupied = destination.appendingPathComponent("README.md")
            try FileManager.default.createDirectory(at: occupied, withIntermediateDirectories: true)
            try "mine".write(to: occupied.appendingPathComponent("kept.txt"), atomically: true, encoding: .utf8)

            // Matched by case rather than by value: `appendingPathComponent`
            // asks the file system, so the URL it builds for an existing
            // directory carries a trailing slash and this one does not.
            #expect {
                try PlanExecutor(processRunner: FakeProcessRunner()).execute(samplePlan, at: destination, force: true)
            } throws: { error in
                guard let error = error as? GenerationError,
                      case let .cannotReplaceDirectory(path) = error
                else { return false }
                return path.lastPathComponent == "README.md"
            }

            #expect(try entries(of: occupied) == ["kept.txt"])
        }
    }

    @Test("a destination that is a file is refused, with or without --force")
    func fileDestination() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("MyApp")
            try "not a directory".write(to: destination, atomically: true, encoding: .utf8)

            #expect(throws: GenerationError.destinationIsNotADirectory(destination)) {
                try PlanExecutor(processRunner: FakeProcessRunner()).execute(samplePlan, at: destination, force: true)
            }
        }
    }

    /// Planned paths come from templates and a validated project name, so this
    /// should be unreachable. It is checked anyway because the alternative to a
    /// check is writing outside the directory the user named.
    @Test("a planned path that escapes the destination is refused", arguments: [
        "../escaped.txt", "/etc/passwd", "App/../../escaped.txt"
    ])
    func escapingPath(path: String) throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("MyApp")
            let plan = GenerationPlan(files: [PlannedFile(path: path, contents: "x")], commands: [])

            #expect(throws: GenerationError.unsafePlannedPath(path)) {
                try PlanExecutor(processRunner: FakeProcessRunner()).execute(plan, at: destination)
            }

            #expect(!FileManager.default.fileExists(atPath: destination.path))
        }
    }

    /// §10.1: a missing generator fails loudly. Failing *before* the write is
    /// what makes it cost nothing.
    @Test("a missing executable is found before anything is written")
    func missingExecutable() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("MyApp")
            let runner = FakeProcessRunner(missing: ["xcodegen"])

            #expect(throws: GenerationError.executableNotFound("xcodegen")) {
                try PlanExecutor(processRunner: runner).execute(samplePlan, at: destination)
            }

            let leftovers = try entries(of: root)
            #expect(leftovers.isEmpty)
            #expect(runner.invocations.isEmpty)
        }
    }
}

@Suite("When a command fails")
struct PlanExecutorRollbackTests {
    @Test("a destination xscaffold created is removed again")
    func rollsBack() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("MyApp")

            #expect(throws: GenerationError.self) {
                try PlanExecutor(processRunner: FakeProcessRunner(failing: "git"))
                    .execute(samplePlan, at: destination)
            }

            let leftovers = try entries(of: root)
            #expect(leftovers.isEmpty)
        }
    }

    /// The other half of the same rule: xscaffold removes what it created and
    /// nothing else. A directory the user made stays, generated files and all —
    /// undoing that would mean deleting files xscaffold cannot tell apart.
    ///
    /// Which means the message has to carry what the rollback could not: the
    /// user is left with a directory whose contents changed under them, and
    /// nothing else will tell them so.
    @Test("a destination the user already had is left as it is, and said to be")
    func doesNotRollBackAPreExistingDestination() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("MyApp")
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)

            let error = #expect(throws: GenerationError.self) {
                try PlanExecutor(processRunner: FakeProcessRunner(failing: "git"))
                    .execute(samplePlan, at: destination)
            }

            #expect(FileManager.default.fileExists(atPath: destination.path))
            #expect(try entries(of: destination) == ["App", "README.md"])
            // Not even a failure leaves the staging area behind.
            #expect(try entries(of: root) == ["MyApp"])

            let description = try #require(error).description
            #expect(description.contains(destination.path))
            #expect(description.contains("fatal: it did not work"), "the reason survives the wrapping")
        }
    }

    /// The message is the only thing between the user and a directory that has
    /// just disappeared, so it has to say which command failed, what it was
    /// for, and what it said — quoted the way they would have typed it.
    @Test("the failure names the command and repeats what it said")
    func explainsTheFailure() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("MyApp")
            let plan = GenerationPlan(
                files: samplePlan.files,
                commands: [PlannedCommand(
                    executable: "git",
                    arguments: ["commit", "--message", "Initial commit"],
                    purpose: "Record the project as generated"
                )]
            )

            let error = #expect(throws: GenerationError.self) {
                try PlanExecutor(processRunner: FakeProcessRunner(failing: "git")).execute(plan, at: destination)
            }

            let description = try #require(error).description
            #expect(description.contains("git commit --message 'Initial commit'"))
            #expect(description.contains("Record the project as generated"))
            #expect(description.contains("fatal: it did not work"))
        }
    }
}
