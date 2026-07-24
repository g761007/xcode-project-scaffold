import Foundation
@testable import ScaffoldCore
import ScaffoldSchema
import Testing

// MARK: - Fixtures

private struct FixtureDidNotValidate: Error {}

/// A small real configuration, validated and planned through the same pipeline
/// `new` uses — the preview shows exactly what would generate, so the tests
/// feed it exactly that.
private func makeFixture() throws -> (validated: ValidatedConfiguration, plan: GenerationPlan) {
    let configuration = ProjectConfiguration(
        project: .init(name: "Bookshelf", bundleIdentifier: "com.example.bookshelf"),
        interface: .init(primary: .swiftUI)
    )
    guard case let .valid(validated, _) = ConfigurationValidator().check(configuration) else {
        throw FixtureDidNotValidate()
    }
    let plan = try GenerationPlanBuilder().makePlan(
        for: validated,
        options: GenerationOptions(initializeGit: true, runGenerator: true)
    )
    return (validated, plan)
}

private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("xscaffold-preview-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try body(root)
}

private func entries(of directory: URL) throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
}

// MARK: - Tests

/// §4.2 / issue #43: the questions end at a preview and a menu, and each
/// option's promise — Generate writes the project, Save writes one file,
/// Cancel writes nothing — is checked against a real directory.
@Suite("The preview and its menu")
struct PreviewSessionTests {
    @Test("choosing Generate executes the plan")
    func generate() throws {
        try withTemporaryDirectory { root in
            let (validated, plan) = try makeFixture()
            let destination = root.appendingPathComponent("Bookshelf")
            let runner = FakeProcessRunner()
            let prompter = ScriptedPrompter(["1"])

            let outcome = try PreviewSession(processRunner: runner).run(
                plan, for: validated, warnings: [], at: destination, using: prompter
            )

            #expect(outcome == .generated)
            #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("scaffold.yml").path))
            #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("project.yml").path))
            #expect(runner.invocations.map(\.executable).contains("git"))
            #expect(runner.invocations.map(\.executable).contains("xcodegen"))
        }
    }

    @Test("choosing Save writes scaffold.yml and nothing else")
    func save() throws {
        try withTemporaryDirectory { root in
            let (validated, plan) = try makeFixture()
            let destination = root.appendingPathComponent("Bookshelf")
            let runner = FakeProcessRunner()
            let prompter = ScriptedPrompter(["2"])

            let outcome = try PreviewSession(processRunner: runner).run(
                plan, for: validated, warnings: [], at: destination, using: prompter
            )

            let manifest = destination.appendingPathComponent("scaffold.yml")
            #expect(outcome == .savedManifest(manifest))
            #expect(try entries(of: destination) == ["scaffold.yml"])
            #expect(runner.invocations.isEmpty)

            // The same bytes generating would have written: the saved manifest
            // round-trips to the configuration that was previewed.
            let saved = try ConfigurationCoder().decode(String(contentsOf: manifest, encoding: .utf8))
            #expect(saved == validated.configuration)
        }
    }

    @Test("choosing Cancel leaves nothing")
    func cancel() throws {
        try withTemporaryDirectory { root in
            let (validated, plan) = try makeFixture()
            let destination = root.appendingPathComponent("Bookshelf")
            let runner = FakeProcessRunner()
            let prompter = ScriptedPrompter(["3"])

            let outcome = try PreviewSession(processRunner: runner).run(
                plan, for: validated, warnings: [], at: destination, using: prompter
            )

            #expect(outcome == .cancelled)
            #expect(!FileManager.default.fileExists(atPath: destination.path))
            #expect(runner.invocations.isEmpty)
        }
    }

    @Test("ended input cancels, exactly as it does during the questions")
    func endedInputCancels() throws {
        try withTemporaryDirectory { root in
            let (validated, plan) = try makeFixture()
            let destination = root.appendingPathComponent("Bookshelf")

            let outcome = try PreviewSession(processRunner: FakeProcessRunner()).run(
                plan, for: validated, warnings: [], at: destination, using: ScriptedPrompter([])
            )

            #expect(outcome == .cancelled)
            #expect(!FileManager.default.fileExists(atPath: destination.path))
        }
    }

    @Test("an answer that is not an option is asked again")
    func reasks() throws {
        try withTemporaryDirectory { root in
            let (validated, plan) = try makeFixture()
            let destination = root.appendingPathComponent("Bookshelf")
            let prompter = ScriptedPrompter(["9", "3"])

            let outcome = try PreviewSession(processRunner: FakeProcessRunner()).run(
                plan, for: validated, warnings: [], at: destination, using: prompter
            )

            #expect(outcome == .cancelled)
            #expect(prompter.timesAsked("What next?") == 2)
        }
    }

    @Test("the preview shows the configuration, the plan and the warnings, then the menu")
    func previewContents() throws {
        try withTemporaryDirectory { root in
            let (validated, plan) = try makeFixture()
            let destination = root.appendingPathComponent("Bookshelf")
            let prompter = ScriptedPrompter(["3"])
            let warning = ValidationIssue(
                code: .invalidBundleIdentifier,
                message: "A warning to display.",
                path: "project.bundleIdentifier"
            )

            _ = try PreviewSession(processRunner: FakeProcessRunner()).run(
                plan, for: validated, warnings: [warning], at: destination, using: prompter
            )

            #expect(prompter.firstIndex(of: "Configuration Preview") != nil)
            #expect(prompter.shown.contains("  Project:       Bookshelf (com.example.bookshelf)"))
            #expect(prompter.shown.contains {
                $0.hasPrefix("  Platform:") && $0.contains("iOS") && $0.contains("SwiftUI")
            })
            #expect(prompter.shown.contains("  \(plan.files.count) files will be created."))
            #expect(prompter.shown.contains("    xcodegen generate"))
            #expect(prompter.shown.contains { $0.contains("Warning XS1301") })
            #expect(prompter.shown.contains("  1) Generate project"))
            #expect(prompter.shown.contains("  2) Save scaffold.yml and exit"))
            #expect(prompter.shown.contains("  3) Cancel"))

            let preview = try #require(prompter.firstIndex(of: "Configuration Preview"))
            let menu = try #require(prompter.firstIndex(of: "What next?"))
            #expect(preview < menu, "the preview comes before the menu")
        }
    }
}
