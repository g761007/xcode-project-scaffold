import Foundation
@testable import ScaffoldCore
import ScaffoldSchema
import Testing

private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("xscaffold-preview-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try body(root)
}

// MARK: - Editing the dependency manager

/// The fifth Edit group (#160). It matters more than the other four: the mode
/// is the answer whose effect on the previewed plan is most visible — a Podfile
/// and a `pod install` appear or vanish with it — so it is the one a reader is
/// most likely to want back after seeing what it did.
@Suite("Editing the dependency manager from the preview")
struct PreviewDependencyEditTests {
    @Test("the Edit menu offers it")
    func theMenuOffersIt() throws {
        try withTemporaryDirectory { root in
            let prompter = ScriptedPrompter(["3", "\u{4}"])

            _ = try runSession(answering: prompter, in: root)

            #expect(prompter.shown.contains("  5) Dependency manager"))
        }
    }

    /// The preview says what the mode is, the same way it says what the
    /// platform and architecture are — every main question has a line.
    @Test("the preview names the mode")
    func thePreviewNamesIt() throws {
        try withTemporaryDirectory { root in
            let prompter = ScriptedPrompter(["6"])

            _ = try runSession(answering: prompter, in: root)

            #expect(prompter.shown.contains("  Dependencies:  None"))
        }
    }

    /// Editing the mode has to move the plan, not just the summary line: the
    /// Podfile and the command that reads it are what the answer is *for*.
    @Test("switching to CocoaPods puts a Podfile and pod install in the plan")
    func editingAddsThePodfile() throws {
        try withTemporaryDirectory { root in
            let prompter = ScriptedPrompter([
                "3", // Edit configuration
                "5", // section: dependency manager
                "3", // CocoaPods
                "1" // back at the menu: Generate
            ])

            let outcome = try runSession(answering: prompter, in: root)

            guard case let .generated(validated, plan, _, _) = outcome else {
                Issue.record("expected .generated, got \(outcome)")
                return
            }
            #expect(validated.configuration.dependencyManagement.mode == .cocoapods)
            #expect(plan.files.contains { $0.path == "Podfile" })
            #expect(plan.commands.contains { $0.displayString.contains("pod install") })
            // The other answers survived the edit.
            #expect(validated.configuration.project.name == "Bookshelf")
            #expect(validated.configuration.architecture.pattern == .minimal)
            // The preview showed again, with the new mode on it.
            #expect(prompter.shown.contains("  Dependencies:  CocoaPods"))
        }
    }

    @Test("switching back to none takes the Podfile away again")
    func editingRemovesThePodfile() throws {
        try withTemporaryDirectory { root in
            var answers = makeAnswers()
            answers.dependencyMode = .cocoapods
            let prompter = ScriptedPrompter([
                "3", // Edit configuration
                "5", // section: dependency manager
                "1", // None
                "1" // Generate
            ])

            let outcome = try runSession(answering: prompter, in: root, answers: answers)

            guard case let .generated(validated, plan, _, _) = outcome else {
                Issue.record("expected .generated, got \(outcome)")
                return
            }
            #expect(validated.configuration.dependencyManagement.mode == .disabled)
            #expect(!plan.files.contains { $0.path == "Podfile" })
            #expect(!plan.commands.contains { $0.displayString.contains("pod install") })
        }
    }

    /// The reason the bases are resolved per mode rather than the mode being
    /// written onto one of them: an edit has to land on the document that
    /// normalization already ran over, or `production` silently loses its pin.
    @Test("editing to CocoaPods under production keeps the Bundler pin")
    func editingUnderProductionNormalizes() throws {
        try withTemporaryDirectory { root in
            let bases = try PresetBases(preset: .production)
            var answers = makeAnswers()
            answers.pattern = .mvvm
            answers.dependencyMode = bases.suggestedMode
            let prompter = ScriptedPrompter([
                "3", // Edit configuration
                "5", // section: dependency manager
                "3", // CocoaPods
                "1" // Generate
            ])

            let outcome = try runSession(
                answering: prompter, in: root, answers: answers, presetBases: bases
            )

            guard case let .generated(validated, plan, _, _) = outcome else {
                Issue.record("expected .generated, got \(outcome)")
                return
            }
            let pods = validated.configuration.dependencyManagement
            #expect(pods.mode == .cocoapods)
            #expect(pods.cocoapods?.bundler?.enabled == true)
            #expect(pods.cocoapods?.bundler?.cocoapodsVersion != nil)
            // Bundler pinned means the Gemfile is real, and pods install through it.
            #expect(plan.files.contains { $0.path == "Gemfile" })
        }
    }
}
