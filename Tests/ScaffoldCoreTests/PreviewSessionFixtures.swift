import Foundation
@testable import ScaffoldCore
import ScaffoldSchema

// Shared by every preview-session suite, the way `ScriptedPrompter` and
// `FakeProcessRunner` are shared by everything that drives one.

/// The answers a `new` run would arrive with: valid, minimal, iOS + SwiftUI.
func makeAnswers() -> PartialProjectConfiguration {
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
func runSession(
    answering prompter: ScriptedPrompter,
    runner: FakeProcessRunner = FakeProcessRunner(),
    in root: URL,
    answers: PartialProjectConfiguration = makeAnswers(),
    presetBases: PresetBases = .none
) throws -> PreviewSession.Outcome {
    try PreviewSession(processRunner: runner, presetBases: presetBases).run(
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
