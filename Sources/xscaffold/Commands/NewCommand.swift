import ArgumentParser
import Foundation
import ScaffoldCore
import ScaffoldSchema

/// The human on-ramp (ADR-0005): a few questions, then the same pipeline `init`
/// runs. It authors a configuration where `init` consumes one, which is why it
/// is a separate command — `init` stays non-interactive and scriptable, and the
/// prompt holds no compatibility rules of its own (§15): it collects answers and
/// lets `validate` decide, re-asking the question a failure points at.
struct NewCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "new",
        abstract: "Create a project by answering a few questions."
    )

    @Argument(help: "The project name. Asked for if omitted.")
    var name: String?

    @Option(name: .customLong("destination"), help: "Where to create the project. Defaults to ./<name>.")
    var destination: String?

    @OptionGroup var runOptions: RunOptions

    @OptionGroup var output: OutputOptions

    @Flag(name: [.customShort("y"), .customLong("yes")], help: "Skip the final confirmation.")
    var assumeYes = false

    @Flag(name: .customLong("force"), help: "Write into a destination that is not empty.")
    var force = false

    @Flag(name: .customLong("validate-build"), help: "Build the generated project before reporting success.")
    var validateBuild = false

    /// `new` is interactive by definition, so the machine-readable path is out:
    /// json forbids interaction (§11.3). The build-flag contradiction `init`
    /// catches applies here too.
    func validate() throws {
        guard output.format != .json else {
            throw ValidationError("--output json is not available for new, which is interactive. "
                + "Use init --config <file> for a machine-readable run.")
        }
        guard !validateBuild || !runOptions.skipGenerate else {
            throw ValidationError("--validate-build cannot be used with --skip-generate: there would be "
                + "no project file to build.")
        }
    }

    func run() throws {
        let reporter = Reporter(for: Self.self, format: .text)
        let prompter = SystemPrompter()

        guard prompter.isInteractive else {
            throw reporter.failure(
                .invalidArguments,
                "new needs a terminal to ask its questions. For a non-interactive run, use "
                    + "init --config <file>, or init <name> --preset <name>."
            )
        }

        let configuration = try collect(using: prompter, reportingTo: reporter).resolved()
        let (validated, warnings) = try checkConfiguration(
            configuration, describedAs: "The answers", reportingTo: reporter
        )
        let plan = try makePlan(for: validated, options: runOptions.generationOptions, reportingTo: reporter)
        let destination = destinationURL(for: configuration)

        guard confirmed(plan, at: destination, using: prompter) else {
            throw cancelled(using: prompter)
        }

        try writePlan(plan, to: destination, force: force, reportingTo: reporter)
        if validateBuild {
            try verifyBuild(of: configuration, at: destination, reportingTo: reporter)
        }
        reportCreated(plan, warnings: warnings, for: configuration, at: destination, to: reporter)
    }
}

extension NewCommand {
    private func collect(
        using prompter: some Prompter,
        reportingTo reporter: Reporter
    ) throws -> PartialProjectConfiguration {
        do {
            return try InteractiveConfiguration().collect(name: name, using: prompter)
        } catch InteractivePromptError.cancelled {
            throw cancelled(using: prompter)
        } catch let InteractivePromptError.unresolvable(issue) {
            throw reporter.failure(.validationFailure, "The answers cannot be generated.", issues: [issue])
        }
    }

    /// Shows the plan and asks once more before writing, unless `--yes`. A "no"
    /// or an ended input is a cancellation, not an answer of "don't generate":
    /// both leave with 130 and nothing on disk.
    private func confirmed(_ plan: GenerationPlan, at destination: URL, using prompter: some Prompter) -> Bool {
        prompter.show("")
        prompter.show("This will create:")
        prompter.show(plan.summary(at: destination))
        guard !assumeYes else { return true }

        prompter.show("")
        prompter.show("Create it? [Y/n]:")
        guard let line = prompter.readLine() else { return false }

        let answer = line.trimmingCharacters(in: .whitespaces).lowercased()
        return answer.isEmpty || answer == "y" || answer == "yes"
    }

    /// A cancellation is not a failure to report through the error channel: it
    /// says so on stderr and leaves with 130, carrying no message of its own.
    private func cancelled(using prompter: some Prompter) -> ExitCode {
        prompter.show("Cancelled; nothing was created.")
        return ExitCode(ScaffoldExitCode.userCancelled.rawValue)
    }

    private func destinationURL(for configuration: ProjectConfiguration) -> URL {
        URL(fileURLWithPath: destination ?? configuration.project.name).standardizedFileURL
    }
}
