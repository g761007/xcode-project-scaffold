import Foundation
import ScaffoldCore
import ScaffoldSchema
import Testing

// The helpers that run the built binary live in RunningTheBinary.swift; the
// suites for `generate` and the deprecated `init` in GenerateCommandTests.swift.

/// §11.4's table is a contract with programs, and a program reads it as a
/// number from a process that has exited. Everything else in the suite tests
/// what xscaffold computes; this tests what it actually returns.
@Suite("Exit codes, from the outside")
struct ExitStatusTests {
    @Test("help and version are requests, not failures")
    func requests() throws {
        #expect(try xscaffold("--help").exitStatus == 0)
        #expect(try xscaffold("--version").exitStatus == 0)
        #expect(try xscaffold("init", "--help").exitStatus == 0)
    }

    /// ArgumentParser answers its own parse failures with `EX_USAGE` (64).
    /// §11.4 says 2, and a caller should not have to know which layer refused.
    @Test("an argument the parser rejects exits 2, not 64", arguments: [
        ["init", "--bogus"], ["nosuchcommand"], ["validate"], ["init", "--output", "yaml"]
    ])
    func parseFailures(arguments: [String]) throws {
        let result = try run(arguments)

        #expect(result.exitStatus == ScaffoldExitCode.invalidArguments.rawValue)
    }

    @Test("a contradiction between flags is refused before anything is written")
    func contradictoryFlags() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("App")
            let result = try xscaffold(
                "init", "App", "--preset", "ios-uikit",
                "--destination", destination.path,
                "--skip-generate", "--validate-build"
            )

            #expect(result.exitStatus == ScaffoldExitCode.invalidArguments.rawValue)
            #expect(!FileManager.default.fileExists(atPath: destination.path))
        }
    }

    @Test("a configuration that cannot be read exits 3")
    func unreadableConfiguration() throws {
        #expect(try xscaffold("validate", "/nowhere/scaffold.yml").exitStatus
            == ScaffoldExitCode.configurationParsingFailure.rawValue)
    }

    @Test("a configuration that cannot be generated exits 4")
    func invalidConfigurationExits() throws {
        try withTemporaryDirectory { root in
            let path = root.appendingPathComponent("scaffold.yml")
            try invalidConfiguration.write(to: path, atomically: true, encoding: .utf8)

            #expect(try xscaffold("validate", path.path).exitStatus
                == ScaffoldExitCode.validationFailure.rawValue)
        }
    }

    @Test("a destination that is already occupied exits 6")
    func occupiedDestination() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("App")
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try "mine".write(to: destination.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

            let result = try xscaffold(
                "init", "App", "--preset", "ios-uikit", "--destination", destination.path,
                "--skip-git", "--skip-generate"
            )

            #expect(result.exitStatus == ScaffoldExitCode.fileConflict.rawValue)
        }
    }
}

/// §11.3: under `--output json`, stdout carries one JSON document and nothing
/// else — on the way out of a failure as much as a success. Every case here
/// decodes the output rather than matching text, because a caller does too.
@Suite("JSON output, from the outside")
struct JSONOutputTests {
    @Test("a successful validate reports no issues")
    func validateSucceeds() throws {
        try withTemporaryDirectory { root in
            let path = root.appendingPathComponent("scaffold.yml")
            try validConfiguration.write(to: path, atomically: true, encoding: .utf8)

            let output = try decoded(xscaffold("validate", path.path, "--output", "json"))

            #expect(output.ok)
            #expect(output.command == "validate")
            #expect(output.exitCode == .success)
            #expect(output.issues?.isEmpty == true)
        }
    }

    @Test("a failing validate is still a document, with the issues in it")
    func validateFails() throws {
        try withTemporaryDirectory { root in
            let path = root.appendingPathComponent("scaffold.yml")
            try invalidConfiguration.write(to: path, atomically: true, encoding: .utf8)

            let result = try xscaffold("validate", path.path, "--output", "json")
            let output = try decoded(result)

            #expect(!output.ok)
            #expect(output.exitCode == .validationFailure)
            #expect(output.issues?.contains { $0.code == .invalidBundleIdentifier } == true)
            #expect(result.exitStatus == output.exitCode.rawValue, "the document agrees with the process")
        }
    }

    /// The hardest case in §11.3: the arguments were wrong, so no command ever
    /// existed to notice that json was asked for.
    @Test("even a parse failure comes back as JSON")
    func parseFailure() throws {
        let result = try xscaffold("init", "--bogus", "--output", "json")
        let output = try decoded(result)

        #expect(!output.ok)
        #expect(output.command == "init")
        #expect(output.exitCode == .invalidArguments)
    }

    @Test("stdout carries the document and nothing else")
    func stdoutIsOnlyJSON() throws {
        try withTemporaryDirectory { root in
            let path = root.appendingPathComponent("scaffold.yml")
            try validConfiguration.write(to: path, atomically: true, encoding: .utf8)

            let result = try xscaffold("validate", path.path, "--output", "json")
            let lines = result.standardOutput.split(separator: "\n", omittingEmptySubsequences: true)

            #expect(lines.count == 1)
        }
    }

    @Test("doctor reports one check per tool it looked for")
    func doctor() throws {
        // Deliberately no assertion on the exit status: whether the tools are
        // installed is a fact about the machine, and CI is not this machine.
        let output = try decoded(xscaffold("doctor", "--output", "json"))

        #expect(output.command == "doctor")
        #expect(output.checks?.isEmpty == false)
        #expect(output.checks?.contains { $0.name == "xcodegen" } == true)
    }
}

/// `new` is the one interactive command, and §11.3/ADR-0005 draw two lines
/// around it: no machine-readable output, and no running without a terminal to
/// answer at. Both are refusals a caller must be able to rely on.
@Suite("The new command refuses what it cannot do")
struct NewCommandGuardTests {
    @Test("new rejects --output json before reading anything")
    func rejectsJSON() throws {
        let result = try xscaffoldWithoutInput("new", "App", "--output", "json")

        #expect(result.exitStatus == ScaffoldExitCode.invalidArguments.rawValue)
    }

    @Test("new without a terminal exits 2 and points at init")
    func refusesWithoutATerminal() throws {
        let result = try xscaffoldWithoutInput("new", "App", "--skip-git", "--skip-generate")

        #expect(result.exitStatus == ScaffoldExitCode.invalidArguments.rawValue)
        #expect(result.standardError.contains("init"))
    }
}

@Suite("What plan promises and init delivers")
struct PlanAndInitTests {
    /// §11.1: "`plan` 與 `init --dry-run` 是同一份實作的兩個入口". Two entrances
    /// that could describe different projects would make the preview useless.
    @Test("plan and init --dry-run describe the same project")
    func sameImplementation() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("App").path
            let planned = try decoded(xscaffold(
                "plan", "App", "--preset", "ios-uikit", "--destination", destination, "--output", "json"
            ))
            let dryRun = try decoded(xscaffold(
                "init", "App", "--preset", "ios-uikit", "--destination", destination,
                "--dry-run", "--output", "json"
            ))

            #expect(planned.plan == dryRun.plan)
            #expect(planned.destination == dryRun.destination)
        }
    }

    @Test("a preview writes nothing")
    func dryRunWritesNothing() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("App")
            try xscaffold("plan", "App", "--preset", "ios-uikit", "--destination", destination.path)

            #expect(!FileManager.default.fileExists(atPath: destination.path))
        }
    }

    /// The plan is a promise about what will be on disk. This is the only test
    /// that checks the promise was kept.
    @Test("what init reports is what init wrote")
    func planMatchesWhatIsWritten() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("App")
            let output = try decoded(xscaffold(
                "init", "App", "--preset", "ios-uikit", "--destination", destination.path,
                "--skip-git", "--skip-generate", "--output", "json"
            ))

            let planned = try #require(output.plan?.files.map(\.path)).sorted()
            #expect(!planned.isEmpty)

            for path in planned {
                let file = destination.appendingPathComponent(path)
                #expect(FileManager.default.fileExists(atPath: file.path), "\(path)")
            }
        }
    }

    /// Skipping the generator has to reach the plan as well as the run, or the
    /// preview would promise a command that never happens.
    @Test("skipping a step removes it from the plan")
    func skipping() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("App").path
            let full = try decoded(xscaffold(
                "plan", "App", "--preset", "ios-uikit", "--destination", destination, "--output", "json"
            ))
            let bare = try decoded(xscaffold(
                "plan", "App", "--preset", "ios-uikit", "--destination", destination,
                "--skip-git", "--skip-generate", "--output", "json"
            ))

            #expect(full.plan?.commands.isEmpty == false)
            #expect(bare.plan?.commands.isEmpty == true)
        }
    }
}
