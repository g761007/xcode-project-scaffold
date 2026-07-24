import Foundation
import ScaffoldCore
import ScaffoldSchema
import Testing

/// §13.3 from the outside: the two destination tiers, their contract names on
/// stderr, and the overwrite list a caller sees before a forced run.
@Suite("Destination rules, from the outside")
struct DestinationRulesTests {
    @Test("a directory with a project in it refuses --force, and says why")
    func hardTier() throws {
        try withTemporaryDirectory { root in
            let path = root.appendingPathComponent("scaffold.yml")
            try validConfiguration.write(to: path, atomically: true, encoding: .utf8)
            let destination = root.appendingPathComponent("Bookshelf")
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            let marker = destination.appendingPathComponent("project.yml")
            try "name: Old".write(to: marker, atomically: true, encoding: .utf8)

            let result = try xscaffold(
                "generate", "--config", path.path, "--destination", destination.path,
                "--yes", "--force", "--skip-git", "--skip-generate"
            )

            #expect(result.exitStatus == ScaffoldExitCode.fileConflict.rawValue)
            #expect(result.standardError.contains("OUTPUT_DIRECTORY_HAS_PROJECT"))
            #expect(try String(contentsOf: marker, encoding: .utf8) == "name: Old")
        }
    }

    @Test("a non-empty directory without a project is refused, naming the flag")
    func softTier() throws {
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
            #expect(result.standardError.contains("OUTPUT_DIRECTORY_NOT_EMPTY"))
            #expect(result.standardError.contains("--force"))
        }
    }

    /// The flow the soft tier exists for: `gh repo create` with README,
    /// LICENSE and .gitignore, cloned, then scaffolded inside.
    @Test("--force moves into a GitHub starter clone and keeps what it did not plan")
    func githubStarter() throws {
        try withTemporaryDirectory { root in
            let path = root.appendingPathComponent("scaffold.yml")
            try validConfiguration.write(to: path, atomically: true, encoding: .utf8)
            let destination = root.appendingPathComponent("Bookshelf")
            try FileManager.default.createDirectory(
                at: destination.appendingPathComponent(".git"),
                withIntermediateDirectories: true
            )
            try "old readme".write(
                to: destination.appendingPathComponent("README.md"), atomically: true, encoding: .utf8
            )
            try "MIT".write(to: destination.appendingPathComponent("LICENSE"), atomically: true, encoding: .utf8)

            let result = try xscaffold(
                "generate", "--config", path.path, "--destination", destination.path,
                "--yes", "--force", "--skip-git", "--skip-generate"
            )

            #expect(result.exitStatus == 0)
            #expect(try String(contentsOf: destination.appendingPathComponent("LICENSE"), encoding: .utf8) == "MIT")
            #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent(".git").path))
        }
    }

    /// The advanced flow: `new` saved a scaffold.yml, the user came back later
    /// and generated in place. One file in the directory, no flag needed.
    @Test("a destination holding only scaffold.yml needs no flag")
    func manifestOnly() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("Bookshelf")
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            let path = destination.appendingPathComponent("scaffold.yml")
            try validConfiguration.write(to: path, atomically: true, encoding: .utf8)

            let result = try xscaffold(
                "generate", "--config", path.path, "--destination", destination.path,
                "--yes", "--skip-git", "--skip-generate"
            )

            #expect(result.exitStatus == 0)
            #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("project.yml").path))
        }
    }

    @Test("plan lists what a forced run would overwrite")
    func planListsOverwrites() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("App")
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try "old readme".write(
                to: destination.appendingPathComponent("README.md"), atomically: true, encoding: .utf8
            )

            let config = root.appendingPathComponent("scaffold.yml")
            try validConfiguration.write(to: config, atomically: true, encoding: .utf8)
            let output = try decoded(xscaffold(
                "plan", "--config", config.path, "--destination", destination.path, "--output", "json"
            ))

            #expect(output.plan?.overwrites?.contains("README.md") == true)
        }
    }

    @Test("a clean destination has no overwrites key at all")
    func cleanPlanHasNoOverwrites() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("App")

            let config = root.appendingPathComponent("scaffold.yml")
            try validConfiguration.write(to: config, atomically: true, encoding: .utf8)
            let output = try decoded(xscaffold(
                "plan", "--config", config.path, "--destination", destination.path, "--output", "json"
            ))

            #expect(output.plan?.overwrites == nil)
        }
    }
}
