import Foundation
import ScaffoldCore
import ScaffoldSchema
import Testing

/// §4.3: `generate` is the non-interactive generation entrance — an existing
/// scaffold.yml in, a project out, and never a prompt where there is no
/// terminal to answer at. Each test here is one line of issue #38's contract.
@Suite("The generate command")
struct GenerateCommandTests {
    @Test("generates from a config, and reports what it wrote")
    func succeeds() throws {
        try withTemporaryDirectory { root in
            let path = root.appendingPathComponent("scaffold.yml")
            try validConfiguration.write(to: path, atomically: true, encoding: .utf8)
            let destination = root.appendingPathComponent("Bookshelf")

            let output = try decoded(xscaffold(
                "generate", "--config", path.path, "--destination", destination.path,
                "--yes", "--skip-git", "--skip-generate", "--output", "json"
            ))

            #expect(output.ok)
            #expect(output.command == "generate")
            #expect(output.exitCode == .success)

            let planned = try #require(output.plan?.files.map(\.path))
            #expect(!planned.isEmpty)
            for path in planned {
                let file = destination.appendingPathComponent(path)
                #expect(FileManager.default.fileExists(atPath: file.path), "\(path)")
            }
        }
    }

    @Test("--config defaults to scaffold.yml in the working directory")
    func defaultConfigurationPath() throws {
        try withTemporaryDirectory { root in
            let path = root.appendingPathComponent("scaffold.yml")
            try validConfiguration.write(to: path, atomically: true, encoding: .utf8)

            let result = try xscaffold("generate", "--yes", "--skip-git", "--skip-generate", in: root)

            #expect(result.exitStatus == 0)
            #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("Bookshelf").path))
        }
    }

    @Test("a configuration that cannot be generated exits 4, with the issues in the document")
    func invalidConfigurationFails() throws {
        try withTemporaryDirectory { root in
            let path = root.appendingPathComponent("scaffold.yml")
            try invalidConfiguration.write(to: path, atomically: true, encoding: .utf8)
            let destination = root.appendingPathComponent("Bookshelf")

            let result = try xscaffold(
                "generate", "--config", path.path, "--destination", destination.path,
                "--yes", "--skip-git", "--skip-generate", "--output", "json"
            )
            let output = try decoded(result)

            #expect(result.exitStatus == ScaffoldExitCode.validationFailure.rawValue)
            #expect(!output.ok)
            #expect(output.issues?.contains { $0.code == .invalidBundleIdentifier } == true)
            #expect(!FileManager.default.fileExists(atPath: destination.path))
        }
    }

    @Test("a configuration that cannot be read exits 3")
    func unreadableConfiguration() throws {
        #expect(try xscaffold("generate", "--yes", "--config", "/nowhere/scaffold.yml").exitStatus
            == ScaffoldExitCode.configurationParsingFailure.rawValue)
    }

    @Test("a destination that is already occupied exits 6")
    func occupiedDestination() throws {
        try withTemporaryDirectory { root in
            let path = root.appendingPathComponent("scaffold.yml")
            try validConfiguration.write(to: path, atomically: true, encoding: .utf8)
            let destination = root.appendingPathComponent("Bookshelf")
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try "mine".write(to: destination.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

            let result = try xscaffold(
                "generate", "--config", path.path, "--destination", destination.path,
                "--yes", "--skip-git", "--skip-generate"
            )

            #expect(result.exitStatus == ScaffoldExitCode.fileConflict.rawValue)
        }
    }

    /// Issue #38: the non-interactive path must never prompt. Without a
    /// terminal the confirmation has no one to ask, so the run is refused
    /// before anything is read — not hung on stdin.
    @Test("without a terminal and without --yes it refuses, and writes nothing")
    func refusesWithoutATerminal() throws {
        try withTemporaryDirectory { root in
            let path = root.appendingPathComponent("scaffold.yml")
            try validConfiguration.write(to: path, atomically: true, encoding: .utf8)
            let destination = root.appendingPathComponent("Bookshelf")

            let result = try xscaffoldWithoutInput(
                "generate", "--config", path.path, "--destination", destination.path,
                "--skip-git", "--skip-generate"
            )

            #expect(result.exitStatus == ScaffoldExitCode.invalidArguments.rawValue)
            #expect(result.standardError.contains("--yes"))
            #expect(!FileManager.default.fileExists(atPath: destination.path))
        }
    }

    /// The CI story: with input closed and --yes passed, nothing is ever asked
    /// and the run completes.
    @Test("--yes runs to completion with input closed")
    func yesNeverPrompts() throws {
        try withTemporaryDirectory { root in
            let path = root.appendingPathComponent("scaffold.yml")
            try validConfiguration.write(to: path, atomically: true, encoding: .utf8)
            let destination = root.appendingPathComponent("Bookshelf")

            let result = try xscaffoldWithoutInput(
                "generate", "--config", path.path, "--destination", destination.path,
                "--yes", "--skip-git", "--skip-generate"
            )

            #expect(result.exitStatus == 0)
            #expect(FileManager.default.fileExists(atPath: destination.path))
        }
    }
}

/// §4.4: `init` still works — the same run it always did — but every use says
/// it is going away and where to go instead.
@Suite("The init command is deprecated")
struct InitDeprecationTests {
    @Test("init --preset still works, and warns on stderr")
    func presetWarns() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("App")
            let result = try xscaffold(
                "init", "App", "--preset", "ios-uikit", "--destination", destination.path,
                "--skip-git", "--skip-generate"
            )

            #expect(result.exitStatus == 0)
            #expect(FileManager.default.fileExists(atPath: destination.path))
            #expect(result.standardError.contains("deprecated"))
            #expect(result.standardError.contains("generate --config"))
            #expect(result.standardError.contains("--variant"))
        }
    }

    @Test("init --config warns too, and the warning stays off a json caller's stdout")
    func configWarnsOnStderrOnly() throws {
        try withTemporaryDirectory { root in
            let path = root.appendingPathComponent("scaffold.yml")
            try validConfiguration.write(to: path, atomically: true, encoding: .utf8)
            let destination = root.appendingPathComponent("Bookshelf")

            let result = try xscaffold(
                "init", "--config", path.path, "--destination", destination.path,
                "--skip-git", "--skip-generate", "--output", "json"
            )

            #expect(result.standardError.contains("deprecated"))

            let lines = result.standardOutput.split(separator: "\n", omittingEmptySubsequences: true)
            #expect(lines.count == 1)
            #expect(try decoded(result).ok)
        }
    }
}
