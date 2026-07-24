import Foundation
@testable import ScaffoldCore
import ScaffoldSchema
import Testing

// MARK: - Fixtures

/// The answers a `new` run would arrive with: valid, minimal, iOS + SwiftUI.
private func makeAnswers() -> PartialProjectConfiguration {
    PartialProjectConfiguration(
        platform: .iOS,
        name: "Bookshelf",
        bundleIdentifier: "com.example.bookshelf",
        interface: .swiftUI,
        pattern: .minimal,
        includeExample: nil,
        environments: []
    )
}

/// Drives one whole session the way `new` does: destination follows the
/// project name (so an edit that renames the project moves the destination),
/// and the plan comes from the real builder.
private func runSession(
    answering prompter: ScriptedPrompter,
    runner: FakeProcessRunner = FakeProcessRunner(),
    in root: URL,
    answers: PartialProjectConfiguration = makeAnswers()
) throws -> PreviewSession.Outcome {
    try PreviewSession(processRunner: runner).run(
        answers: answers,
        destination: { root.appendingPathComponent($0.project.name) },
        makePlan: {
            try GenerationPlanBuilder().makePlan(
                for: $0,
                options: GenerationOptions(initializeGit: true, runGenerator: true)
            )
        },
        using: prompter
    )
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

// MARK: - The three terminal options

/// §4.2 / issue #43: the questions end at a preview and a menu, and each
/// option's promise — Generate writes the project, Save writes one file,
/// Cancel writes nothing — is checked against a real directory.
@Suite("The preview and its menu")
struct PreviewSessionTests {
    @Test("choosing Generate executes the plan")
    func generate() throws {
        try withTemporaryDirectory { root in
            let runner = FakeProcessRunner()
            let prompter = ScriptedPrompter(["1"])

            let outcome = try runSession(answering: prompter, runner: runner, in: root)

            guard case let .generated(validated, _, _, destination) = outcome else {
                Issue.record("expected .generated, got \(outcome)")
                return
            }
            #expect(validated.configuration.project.name == "Bookshelf")
            #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("scaffold.yml").path))
            #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("project.yml").path))
            #expect(runner.invocations.map(\.executable).contains("git"))
            #expect(runner.invocations.map(\.executable).contains("xcodegen"))
        }
    }

    @Test("choosing Save writes scaffold.yml and nothing else")
    func save() throws {
        try withTemporaryDirectory { root in
            let runner = FakeProcessRunner()
            let prompter = ScriptedPrompter(["2"])

            let outcome = try runSession(answering: prompter, runner: runner, in: root)

            let destination = root.appendingPathComponent("Bookshelf")
            let manifest = destination.appendingPathComponent("scaffold.yml")
            guard case let .savedManifest(saved) = outcome else {
                Issue.record("expected .savedManifest, got \(outcome)")
                return
            }
            #expect(saved == manifest)
            #expect(try entries(of: destination) == ["scaffold.yml"])
            #expect(runner.invocations.isEmpty)

            // The same bytes generating would have written: the saved manifest
            // round-trips to the configuration that was previewed.
            let decoded = try ConfigurationCoder().decode(String(contentsOf: manifest, encoding: .utf8))
            #expect(decoded == makeAnswers().resolved())
        }
    }

    @Test("choosing Cancel leaves nothing")
    func cancel() throws {
        try withTemporaryDirectory { root in
            let runner = FakeProcessRunner()

            let outcome = try runSession(answering: ScriptedPrompter(["6"]), runner: runner, in: root)

            guard case .cancelled = outcome else {
                Issue.record("expected .cancelled, got \(outcome)")
                return
            }
            #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("Bookshelf").path))
            #expect(runner.invocations.isEmpty)
        }
    }

    @Test("ended input cancels, exactly as it does during the questions")
    func endedInputCancels() throws {
        try withTemporaryDirectory { root in
            let outcome = try runSession(answering: ScriptedPrompter([]), in: root)

            guard case .cancelled = outcome else {
                Issue.record("expected .cancelled, got \(outcome)")
                return
            }
            #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("Bookshelf").path))
        }
    }

    @Test("an answer that is not an option is asked again")
    func reasks() throws {
        try withTemporaryDirectory { root in
            let prompter = ScriptedPrompter(["9", "6"])

            _ = try runSession(answering: prompter, in: root)

            #expect(prompter.timesAsked("What next?") == 2)
        }
    }

    @Test("the preview shows the configuration and the plan, then the menu")
    func previewContents() throws {
        try withTemporaryDirectory { root in
            let prompter = ScriptedPrompter(["6"])

            _ = try runSession(answering: prompter, in: root)

            #expect(prompter.shown.contains("  Project:       Bookshelf (com.example.bookshelf)"))
            #expect(prompter.shown.contains {
                $0.hasPrefix("  Platform:") && $0.contains("iOS") && $0.contains("SwiftUI")
            })
            #expect(prompter.shown.contains { $0.hasSuffix("files will be created.") })
            #expect(prompter.shown.contains("    xcodegen generate"))
            #expect(prompter.shown.contains("  1) Generate project"))
            #expect(prompter.shown.contains("  2) Save scaffold.yml and exit"))
            #expect(prompter.shown.contains("  3) Edit configuration"))
            #expect(prompter.shown.contains("  4) Show complete file plan"))
            #expect(prompter.shown.contains("  5) Show resolved configuration"))
            #expect(prompter.shown.contains("  6) Cancel"))

            let preview = try #require(prompter.firstIndex(of: "Configuration Preview"))
            let menu = try #require(prompter.firstIndex(of: "What next?"))
            #expect(preview < menu, "the preview comes before the menu")
        }
    }
}

// MARK: - Editing

/// Issue #44: Edit re-asks one section, keeps every other answer, and comes
/// back to a preview that reflects the change — as many rounds as it takes.
@Suite("Editing from the preview")
struct PreviewEditTests {
    @Test("editing the project section renames the project, and Generate follows")
    func editThenGenerate() throws {
        try withTemporaryDirectory { root in
            let runner = FakeProcessRunner()
            let prompter = ScriptedPrompter([
                "3", // Edit configuration
                "1", // section: project name and bundle identifier
                "Shelf", // new name
                "", // bundle identifier: take the derived default
                "1" // back at the menu: Generate
            ])

            let outcome = try runSession(answering: prompter, runner: runner, in: root)

            guard case let .generated(validated, _, _, destination) = outcome else {
                Issue.record("expected .generated, got \(outcome)")
                return
            }
            #expect(validated.configuration.project.name == "Shelf")
            #expect(validated.configuration.project.bundleIdentifier == "com.example.shelf")
            // The other answers survived the edit.
            #expect(validated.configuration.architecture.pattern == .minimal)
            // The destination followed the rename.
            #expect(destination.lastPathComponent == "Shelf")
            #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("scaffold.yml").path))
            #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("Bookshelf").path))
            // The preview showed again after the edit, reflecting the change.
            #expect(prompter.timesAsked("Configuration Preview") == 2)
            #expect(prompter.shown.contains("  Project:       Shelf (com.example.shelf)"))
        }
    }

    @Test("several rounds of edits, then Cancel still leaves nothing")
    func multiRoundEditsThenCancel() throws {
        try withTemporaryDirectory { root in
            let runner = FakeProcessRunner()
            let prompter = ScriptedPrompter([
                "3", // Edit
                "3", // section: architecture
                "2", // MVVM
                "y", // include the example
                "3", // Edit again
                "4", // section: build environments
                "2", // the standard set
                "6" // Cancel
            ])

            let outcome = try runSession(answering: prompter, runner: runner, in: root)

            guard case .cancelled = outcome else {
                Issue.record("expected .cancelled, got \(outcome)")
                return
            }
            #expect(prompter.timesAsked("What next?") == 3, "one menu per round")
            #expect(prompter.timesAsked("Configuration Preview") == 3)
            #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("Bookshelf").path))
            #expect(runner.invocations.isEmpty)
        }
    }

    @Test("an edit that breaks validation re-asks the question the failure points at")
    func editRevalidates() throws {
        try withTemporaryDirectory { root in
            let prompter = ScriptedPrompter([
                "3", // Edit
                "2", // section: platform and interface
                "2", // platform: macOS
                "1", // interface: UIKit — invalid on macOS (XS1002)
                "3", // interface asked again: AppKit
                "6" // Cancel
            ])

            let outcome = try runSession(answering: prompter, in: root)

            guard case .cancelled = outcome else {
                Issue.record("expected .cancelled, got \(outcome)")
                return
            }
            #expect(prompter.timesAsked("Interface") == 2, "the broken answer was asked again")
            #expect(prompter.shown.contains {
                $0.hasPrefix("  Platform:") && $0.contains("macOS") && $0.contains("AppKit")
            })
        }
    }

    @Test("ended input while choosing a section cancels")
    func endedInputDuringSectionChoice() throws {
        try withTemporaryDirectory { root in
            let outcome = try runSession(answering: ScriptedPrompter(["3"]), in: root)

            guard case .cancelled = outcome else {
                Issue.record("expected .cancelled, got \(outcome)")
                return
            }
            #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("Bookshelf").path))
        }
    }
}

// MARK: - Showing more

/// Issue #45: the two Show options lengthen what the preview said, then come
/// back to the menu — only an edit earns a fresh preview.
@Suite("Showing more from the menu")
struct PreviewShowTests {
    @Test("Show complete file plan lists every file, then returns to the menu")
    func showFiles() throws {
        try withTemporaryDirectory { root in
            let prompter = ScriptedPrompter(["4", "6"])

            let outcome = try runSession(answering: prompter, in: root)

            guard case .cancelled = outcome else {
                Issue.record("expected .cancelled, got \(outcome)")
                return
            }
            #expect(prompter.shown.contains("Files:"))
            #expect(prompter.shown.contains("  project.yml"))
            #expect(prompter.shown.contains("  scaffold.yml"))
            #expect(prompter.shown.contains { $0.hasPrefix("  xcodegen generate") })
            #expect(prompter.timesAsked("What next?") == 2, "back to the menu, not to a fresh preview")
            #expect(prompter.timesAsked("Configuration Preview") == 1)
        }
    }

    @Test("Show resolved configuration renders the manifest, then returns to the menu")
    func showResolvedConfiguration() throws {
        try withTemporaryDirectory { root in
            let prompter = ScriptedPrompter(["5", "6"])

            let outcome = try runSession(answering: prompter, in: root)

            guard case .cancelled = outcome else {
                Issue.record("expected .cancelled, got \(outcome)")
                return
            }
            #expect(prompter.shown.contains { $0.contains("bundleIdentifier: com.example.bookshelf") })
            #expect(prompter.timesAsked("What next?") == 2)
            #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("Bookshelf").path))
        }
    }
}
