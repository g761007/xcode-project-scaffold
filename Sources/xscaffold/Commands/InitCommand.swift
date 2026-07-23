import ArgumentParser
import Foundation
import ScaffoldCore
import ScaffoldSchema

/// The one command that writes anything (§1): configuration in, project out.
///
/// It holds no rules of its own — parsing, validation, planning and writing all
/// belong to `ScaffoldCore` (§18.2). What lives here is the mapping between
/// those steps and the CLI's contract: which flags mean what, and which failure
/// exits with which code.
struct InitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Create a project from a preset or a scaffold.yml.",
        discussion: """
        Pass exactly one of --preset or --config.

          xscaffold init MyApp --preset ios-uikit
          xscaffold init --config scaffold.yml

        Available presets:
        \(Preset.all.map { "  \($0.name.padding(toLength: 14, withPad: " ", startingAt: 0))\($0.summary)" }
            .joined(separator: "\n"))
        """
    )

    @OptionGroup var project: ProjectOptions
    @OptionGroup var runOptions: RunOptions
    @OptionGroup var output: OutputOptions

    @Flag(name: .customLong("dry-run"), help: "Show what would be created, and stop.")
    var dryRun = false

    @Flag(name: .customLong("force"), help: "Write into a destination that is not empty.")
    var force = false

    @Flag(name: .customLong("validate-build"), help: "Build the generated project before reporting success.")
    var validateBuild = false

    /// Contradictions between flags, caught before anything is read or written.
    /// Both of these would otherwise surface as xcodebuild failing to find a
    /// project file — a true statement about the wrong problem.
    func validate() throws {
        guard !validateBuild || !runOptions.skipGenerate else {
            throw ValidationError("--validate-build cannot be used with --skip-generate: there would be "
                + "no project file to build.")
        }
        guard !validateBuild || !dryRun else {
            throw ValidationError("--validate-build cannot be used with --dry-run: a dry run creates "
                + "nothing to build.")
        }
    }

    func run() throws {
        let reporter = Reporter(for: Self.self, format: output.format)

        // Same implementation as `plan`, under this command's name: a preview
        // that could disagree with the run it previews would be worse than none.
        guard !dryRun else {
            return try reportPlan(for: project, run: runOptions, to: reporter)
        }

        let (configuration, warnings) = try resolveConfiguration(project, reportingTo: reporter)
        let plan = try makePlan(for: configuration, options: runOptions.generationOptions, reportingTo: reporter)
        let destination = project.destinationURL(for: configuration)

        try write(plan, to: destination, reportingTo: reporter)
        if validateBuild {
            try verifyBuild(of: configuration, at: destination, reportingTo: reporter)
        }

        report(plan, warnings: warnings, for: configuration, at: destination, to: reporter)
    }
}

// MARK: - Doing it

extension InitCommand {
    private func write(_ plan: GenerationPlan, to destination: URL, reportingTo reporter: Reporter) throws {
        do {
            try PlanExecutor().execute(plan, at: destination, force: force)
        } catch let error as GenerationError {
            throw reporter.failure(error.exitCode, "\(error)")
        } catch {
            throw reporter.failure(.generationFailure, "\(error)")
        }
    }

    /// The project stays if the build fails. Generation succeeded; what failed
    /// is a check on top of it, and deleting the evidence would be a strange way
    /// to report a compiler error.
    private func verifyBuild(
        of configuration: ProjectConfiguration,
        at destination: URL,
        reportingTo reporter: Reporter
    ) throws {
        reporter.note("Building \(configuration.project.name)…")

        do {
            try BuildValidator().validate(configuration, at: destination)
        } catch let error as BuildValidationError {
            throw reporter.failure(error.exitCode, "\(error)")
        } catch let error as GenerationError {
            // Xcode missing entirely is a missing requirement, not a failed
            // build: a different code, and a different thing to do about it.
            throw reporter.failure(error.exitCode, "\(error)")
        } catch {
            throw reporter.failure(.buildValidationFailure, "\(error)")
        }
    }
}

// MARK: - Saying what happened

extension InitCommand {
    private func report(
        _ plan: GenerationPlan,
        warnings: [ValidationIssue],
        for configuration: ProjectConfiguration,
        at destination: URL,
        to reporter: Reporter
    ) {
        reporter.succeed(
            CommandOutput(
                command: reporter.command,
                exitCode: .success,
                issues: warnings,
                destination: destination.path,
                plan: PlanSummary(plan)
            ),
            text: text(plan, for: configuration, at: destination)
        )
    }

    private func text(
        _ plan: GenerationPlan,
        for configuration: ProjectConfiguration,
        at destination: URL
    ) -> String {
        var lines = ["Created \(configuration.project.name) at:", plan.summary(at: destination), ""]

        guard !runOptions.skipGenerate else {
            // Deliberately not "run `make generate`": which recipe produces the
            // project file is the generated Makefile's business, and the README
            // that has just been written says so.
            lines.append("There is no project file yet. The generated README.md says how to produce one.")
            return lines.joined(separator: "\n")
        }

        lines.append("Open it with:")
        lines.append("  open \(destination.appendingPathComponent(configuration.projectFileName).path)")
        return lines.joined(separator: "\n")
    }
}
