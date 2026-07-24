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

        let (validated, warnings) = try resolveConfiguration(project, reportingTo: reporter)
        let plan = try makePlan(for: validated, options: runOptions.generationOptions, reportingTo: reporter)
        let configuration = validated.configuration
        let destination = project.destinationURL(for: configuration)

        try writePlan(plan, to: destination, force: force, reportingTo: reporter)
        if validateBuild {
            try verifyBuild(of: configuration, at: destination, reportingTo: reporter)
        }

        reportCreated(plan, warnings: warnings, for: configuration, at: destination, to: reporter)
    }
}
