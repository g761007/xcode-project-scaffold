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

/// Answers that read pods, so the plan calls something this machine might not
/// have.
private func podAnswers() -> PartialProjectConfiguration {
    var answers = makeAnswers()
    answers.dependencyMode = .cocoapods
    return answers
}

/// Saying what is missing before anything is written (#161).
///
/// Without this, a `cocoapods` project on a machine with no CocoaPods generates
/// every file, runs the generator, and only then fails at `pod install` — with
/// the project already on disk. `doctor` knew all along; nobody thought to run
/// it first.
@Suite("Warning about tools this machine does not have")
struct PreviewEnvironmentWarningTests {
    @Test("a missing pod is named at the preview, with how to install it")
    func missingPodIsNamed() throws {
        try withTemporaryDirectory { root in
            let runner = FakeProcessRunner(missing: ["pod"])
            let prompter = ScriptedPrompter(["6"])

            _ = try runSession(answering: prompter, runner: runner, in: root, answers: podAnswers())

            let warning = try #require(prompter.shown.first { $0.hasPrefix("  Warning: pod") })
            #expect(warning.contains("not installed"))
            #expect(warning.contains("brew install cocoapods"))
        }
    }

    /// The common case has to stay quiet, or the warning becomes something
    /// people learn to scroll past.
    @Test("a machine with the tools says nothing")
    func nothingWhenPresent() throws {
        try withTemporaryDirectory { root in
            let prompter = ScriptedPrompter(["6"])

            _ = try runSession(answering: prompter, in: root, answers: podAnswers())

            #expect(!prompter.shown.contains { $0.hasPrefix("  Warning: ") })
        }
    }

    /// A check about tools the run will not call is noise, and noise about
    /// CocoaPods is exactly the noise an SPM project should never see.
    @Test("a project that reads no pods is never warned about them",
          arguments: [DependencyMode.disabled, .spm])
    func noPodWarningWithoutPods(mode: DependencyMode) throws {
        try withTemporaryDirectory { root in
            let runner = FakeProcessRunner(missing: ["pod", "bundle"])
            var answers = makeAnswers()
            answers.dependencyMode = mode
            let prompter = ScriptedPrompter(["6"])

            _ = try runSession(answering: prompter, runner: runner, in: root, answers: answers)

            #expect(!prompter.shown.contains { $0.hasPrefix("  Warning: pod") })
            #expect(!prompter.shown.contains { $0.hasPrefix("  Warning: bundle") })
        }
    }

    /// With Bundler, `bundle exec` provides pod itself, so `bundle` is the tool
    /// that matters and `pod` is not. The plan says which one it will call, and
    /// the warning follows the plan.
    @Test("a Bundler project is warned about bundle, not pod")
    func bundlerProjectWarnsAboutBundle() throws {
        try withTemporaryDirectory { root in
            let bases = try PresetBases(preset: .production)
            var answers = makeAnswers()
            answers.pattern = .mvvm
            answers.dependencyMode = .cocoapods
            let runner = FakeProcessRunner(missing: ["pod", "bundle"])
            let prompter = ScriptedPrompter(["6"])

            _ = try runSession(
                answering: prompter, runner: runner, in: root, answers: answers, presetBases: bases
            )

            #expect(prompter.shown.contains { $0.hasPrefix("  Warning: bundle") })
            #expect(!prompter.shown.contains { $0.hasPrefix("  Warning: pod") })
        }
    }

    /// The warning informs; it does not refuse. Save still writes the manifest,
    /// which is the whole point of finding out at this moment rather than after
    /// the project exists.
    @Test("the warning does not stop the run")
    func theWarningDoesNotBlock() throws {
        try withTemporaryDirectory { root in
            let runner = FakeProcessRunner(missing: ["pod"])
            let prompter = ScriptedPrompter(["2"])

            let outcome = try runSession(
                answering: prompter, runner: runner, in: root, answers: podAnswers()
            )

            guard case let .savedManifest(saved) = outcome else {
                Issue.record("expected .savedManifest, got \(outcome)")
                return
            }
            #expect(FileManager.default.fileExists(atPath: saved.path))
            #expect(prompter.shown.contains { $0.hasPrefix("  Warning: pod") })
        }
    }

    /// It is not a `ValidationIssue`, and must not arrive as one: validation is
    /// pure by design, and the same `scaffold.yml` has to reach the same verdict
    /// on a machine with CocoaPods and a machine without.
    @Test("it is not carried as a validation warning")
    func notAValidationIssue() throws {
        try withTemporaryDirectory { root in
            let runner = FakeProcessRunner(missing: ["pod"])
            let prompter = ScriptedPrompter(["2"])

            _ = try runSession(answering: prompter, runner: runner, in: root, answers: podAnswers())

            let issues = ConfigurationValidator().validate(podAnswers().resolved())
            #expect(!issues.contains { $0.message.contains("not installed") })
        }
    }
}

private struct ValidationFailed: Error {}

/// The same question asked of the plan directly, without a session around it.
@Suite("Which tools a plan needs")
struct MissingToolsTests {
    private func plan(
        for answers: PartialProjectConfiguration,
        options: GenerationOptions
    ) throws -> (GenerationPlan, ProjectConfiguration) {
        let configuration = answers.resolved()
        guard case let .valid(validated, _) = ConfigurationValidator().check(configuration) else {
            throw ValidationFailed()
        }
        let plan = try GenerationPlanBuilder().makePlan(for: validated, options: options)
        return (plan, configuration)
    }

    /// A run that will not call the generator must not be warned about one.
    /// This is why the plan decides and the configuration does not: the
    /// configuration cannot know what this run skips.
    @Test("skipping the generator drops the warning about it")
    func skippingTheGeneratorDropsItsWarning() throws {
        let runner = FakeProcessRunner(missing: ["xcodegen"])
        let doctor = EnvironmentDoctor(processRunner: runner)

        let (withGenerator, configuration) = try plan(
            for: makeAnswers(),
            options: GenerationOptions(initializeGit: false, runGenerator: true)
        )
        let (without, _) = try plan(
            for: makeAnswers(),
            options: GenerationOptions(initializeGit: false, runGenerator: false)
        )

        #expect(doctor.missingTools(calledBy: withGenerator, for: configuration)
            .contains { $0.name == "xcodegen" })
        #expect(doctor.missingTools(calledBy: without, for: configuration).isEmpty)
    }

    /// Not only CocoaPods: anything the plan will run and the machine lacks.
    @Test("a missing git is reported when the plan initialises a repository")
    func missingGitIsReported() throws {
        let runner = FakeProcessRunner(missing: ["git"])
        let doctor = EnvironmentDoctor(processRunner: runner)

        let (plan, configuration) = try plan(
            for: makeAnswers(),
            options: GenerationOptions(initializeGit: true, runGenerator: false)
        )

        #expect(doctor.missingTools(calledBy: plan, for: configuration).map(\.name) == ["git"])
    }
}
