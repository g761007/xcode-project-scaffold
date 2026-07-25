import Foundation
import ScaffoldCore
import ScaffoldSchema
import Testing

/// `examples/`, found from this file rather than from the working directory,
/// which under `swift test` is not the repository.
private let examplesDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent() // CommandLineTests
    .deletingLastPathComponent() // Tests
    .deletingLastPathComponent() // repository root
    .appendingPathComponent("examples")

/// Discovered rather than listed, so an example added without a test is not a
/// thing that can happen.
private let examples: [String] = {
    let contents = (try? FileManager.default.contentsOfDirectory(atPath: examplesDirectory.path)) ?? []
    return contents.filter { $0.hasSuffix(".yml") }.sorted()
}()

/// A committed example that no longer validates is worse than no example: it
/// is the first thing a new user copies, and they meet the schema through a
/// file that was right six months ago.
@Suite("The example configurations")
struct ExampleConfigurationTests {
    /// If the directory ever goes missing or empty, every test below would
    /// pass by having nothing to run.
    @Test("there are examples to check")
    func examplesExist() {
        #expect(examples.count >= 4, "\(examplesDirectory.path)")
    }

    @Test("every example validates as written", arguments: examples)
    func validates(name: String) throws {
        let result = try xscaffold("validate", examplesDirectory.appendingPathComponent(name).path)

        #expect(result.exitStatus == 0, "\(name): \(result.standardError)")
    }

    /// Validation says the configuration is coherent; planning says this
    /// version can actually build a file list from it. A combination that
    /// validates and then has no templates would pass the test above.
    @Test("every example plans a project", arguments: examples)
    func plans(name: String) throws {
        let output = try decoded(run([
            "plan", "--config", examplesDirectory.appendingPathComponent(name).path,
            "--output", "json"
        ]))

        #expect(output.ok, "\(name)")
        #expect((output.plan?.files.count ?? 0) > 5, "\(name)")
    }

    /// The point of the directory: these are files someone has edited down to
    /// what they chose, not the resolved document `config example` prints. An
    /// example that carried every field would teach the opposite of what a
    /// `scaffold.yml` in a repository looks like.
    @Test("an example states what it chose, not every field", arguments: examples)
    func statesOnlyWhatItChose(name: String) throws {
        let contents = try String(
            contentsOf: examplesDirectory.appendingPathComponent(name), encoding: .utf8
        )

        // Fields that always resolve to the same thing and are never worth
        // stating: their presence would mean the file was pasted from the
        // resolved document rather than written.
        for field in ["languageMode:", "type: application", "generator:", "defaultBranch:"] {
            #expect(!contents.contains(field), "\(name) states \(field)")
        }
    }

    /// A secret in a committed example is a secret in everyone's clone.
    @Test("no example carries a credential", arguments: examples)
    func carriesNoCredentials(name: String) throws {
        let contents = try String(
            contentsOf: examplesDirectory.appendingPathComponent(name), encoding: .utf8
        )

        // A credential in a URL is the shape this project already masks
        // elsewhere; the example that documents private specs repos is exactly
        // where one would end up by accident.
        #expect(contents.wholeMatch(of: /(?s).*https:\/\/[^\/\s]+:[^@\s]+@.*/) == nil, "\(name)")
    }
}
