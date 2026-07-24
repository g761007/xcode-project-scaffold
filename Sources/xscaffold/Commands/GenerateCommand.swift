import ArgumentParser
import Foundation
import ScaffoldCore
import ScaffoldSchema

/// The non-interactive generation entrance (§4.3): an existing scaffold.yml in,
/// a project out, scriptable end to end. It takes over `init --config`, and
/// adds the one thing `init` never had — a summary of what is about to happen,
/// confirmed at the terminal or by `--yes`, never by silence.
struct GenerateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "Create a project from an existing scaffold.yml.",
        discussion: """
          xscaffold generate
          xscaffold generate --config configs/app.yml --destination ../App
          xscaffold generate --yes --output json

        The configuration defaults to ./scaffold.yml. A run without --yes shows
        a summary and waits for confirmation, so it needs a terminal; pass --yes
        anywhere there is none.
        """
    )

    @Option(name: .customLong("config"), help: "Path to a scaffold.yml. Defaults to ./scaffold.yml.")
    var configurationPath: String = "scaffold.yml"

    @Option(name: .customLong("destination"), help: "Where to create the project. Defaults to ./<name>.")
    var destination: String?

    @OptionGroup var runOptions: RunOptions
    @OptionGroup var output: OutputOptions

    @Flag(name: [.customShort("y"), .customLong("yes")], help: "Skip the confirmation.")
    var assumeYes = false

    @Flag(name: .customLong("force"), help: "Write into a destination that is not empty.")
    var force = false

    @Flag(name: .customLong("validate-build"), help: "Build the generated project before reporting success.")
    var validateBuild = false

    /// The same contradiction `init` catches, for the same reason.
    func validate() throws {
        guard !validateBuild || !runOptions.skipGenerate else {
            throw ValidationError("--validate-build cannot be used with --skip-generate: there would be "
                + "no project file to build.")
        }
    }

    func run() throws {
        let reporter = Reporter(for: Self.self, format: output.format)
        let prompter = SystemPrompter()

        // The confirmation is a question, and without --yes there has to be a
        // terminal to answer it at. Refused up front, before anything is read,
        // rather than hanging a pipeline on a prompt it can never see (§4.3).
        guard assumeYes || prompter.isInteractive else {
            throw reporter.failure(
                .invalidArguments,
                "generate needs a terminal to confirm. Pass --yes to skip the confirmation."
            )
        }

        let configuration = try readConfiguration(at: configurationPath, reportingTo: reporter)
        let (validated, warnings) = try checkConfiguration(
            configuration, describedAs: "The configuration", reportingTo: reporter
        )
        for warning in warnings {
            reporter.note(warning.report)
        }

        let plan = try makePlan(for: validated, options: runOptions.generationOptions, reportingTo: reporter)
        let destination = destinationURL(for: validated.configuration)

        guard confirmed(plan, at: destination, using: prompter, assumeYes: assumeYes) else {
            throw cancelled(using: prompter, reportingTo: reporter)
        }

        try writePlan(plan, to: destination, force: force, reportingTo: reporter)
        if validateBuild {
            try verifyBuild(of: validated.configuration, at: destination, reportingTo: reporter)
        }
        reportCreated(plan, warnings: warnings, for: validated.configuration, at: destination, to: reporter)
    }

    private func destinationURL(for configuration: ProjectConfiguration) -> URL {
        // Standardised so that a path with `..` in it still yields the right
        // parent directory, which is where the staging area goes.
        URL(fileURLWithPath: destination ?? configuration.project.name).standardizedFileURL
    }
}
