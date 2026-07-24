import ArgumentParser
import Foundation
import ScaffoldCore
import ScaffoldSchema

/// The human on-ramp (ADR-0005): a few questions, then the same pipeline
/// `generate` runs. It authors a configuration where `generate` consumes one,
/// which is why it is a separate command — `generate` stays non-interactive and
/// scriptable, and the prompt holds no compatibility rules of its own (§15): it
/// collects answers and lets `validate` decide, re-asking the question a
/// failure points at.
///
/// `--variant` answers the platform and interface questions from the command
/// line (§17.1); with `--yes` as well there is no question left standing, and
/// `new MyApp --variant ios-uikit --yes` is the one-line generation that
/// replaces `init --preset`.
struct NewCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "new",
        abstract: "Create a project by answering a few questions.",
        discussion: """
          xscaffold new MyApp
          xscaffold new MyApp --variant ios-uikit --yes

        Available variants:
        \(Variant.all.map { "  \($0.name.padding(toLength: 14, withPad: " ", startingAt: 0))\($0.summary)" }
            .joined(separator: "\n"))
        """
    )

    @Argument(help: "The project name. Asked for if omitted.")
    var name: String?

    @Option(name: .customLong("destination"), help: "Where to create the project. Defaults to ./<name>.")
    var destination: String?

    @Option(name: .customLong("variant"), help: "A platform and interface combination; answers those two questions.")
    var variantName: String?

    /// Defined only to be refused with a pointer at `--variant` (§17.1): the
    /// four combinations hung off `--preset` until v0.4, and an unknown-option
    /// error would leave whoever typed it to work the move out alone. Hidden,
    /// so the help never advertises what exists only to say no.
    @Option(name: .customLong("preset"), help: .hidden)
    var presetName: String?

    @OptionGroup var runOptions: RunOptions

    @OptionGroup var output: OutputOptions

    @Flag(
        name: [.customShort("y"), .customLong("yes")],
        help: "Skip the final confirmation. With --variant, skip the questions too and take every default."
    )
    var assumeYes = false

    @Flag(name: .customLong("force"), help: "Write into a destination that is not empty.")
    var force = false

    @Flag(name: .customLong("validate-build"), help: "Build the generated project before reporting success.")
    var validateBuild = false

    /// `new` is interactive by definition, so the machine-readable path is out:
    /// json forbids interaction (§11.3). The build-flag contradiction
    /// `generate` catches applies here too.
    func validate() throws {
        guard presetName == nil else {
            throw ValidationError("new has no --preset — did you mean --variant? The platform "
                + "combinations that used to hang off --preset are now variants.")
        }
        if let variantName, Variant.named(variantName) == nil {
            let known = Variant.all.map(\.name).joined(separator: ", ")
            throw ValidationError("There is no variant named '\(variantName)'. Try one of: \(known).")
        }
        guard output.format != .json else {
            throw ValidationError("--output json is not available for new, which is interactive. "
                + "Use generate --config <file> for a machine-readable run.")
        }
        guard !validateBuild || !runOptions.skipGenerate else {
            throw ValidationError("--validate-build cannot be used with --skip-generate: there would be "
                + "no project file to build.")
        }
    }

    func run() throws {
        let reporter = Reporter(for: Self.self, format: .text)
        let prompter = SystemPrompter()
        let variant = variantName.flatMap(Variant.named)

        let configuration: ProjectConfiguration
        if let variant, assumeYes {
            // §4.2's one-line generation, the successor to init --preset: every
            // question is answered — platform and interface by the variant, the
            // name by its argument, the rest by their defaults — so no terminal
            // is needed and none is consulted.
            guard let name else {
                throw reporter.failure(
                    .invalidArguments,
                    "A variant does not name the project. Try: xscaffold new MyApp --variant \(variant.name) --yes"
                )
            }
            configuration = variant.configuration(projectName: name)
        } else {
            guard prompter.isInteractive else {
                throw reporter.failure(
                    .invalidArguments,
                    "new needs a terminal to ask its questions. For a non-interactive run, use "
                        + "generate --config <file>, or new <name> --variant <name> --yes."
                )
            }
            configuration = try collect(variant: variant, using: prompter, reportingTo: reporter).resolved()
        }

        let (validated, warnings) = try checkConfiguration(
            configuration, describedAs: "The answers", reportingTo: reporter
        )
        let plan = try makePlan(for: validated, options: runOptions.generationOptions, reportingTo: reporter)
        let destination = destinationURL(for: configuration)

        guard confirmed(plan, at: destination, using: prompter, assumeYes: assumeYes) else {
            throw cancelled(using: prompter, reportingTo: reporter)
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
        variant: Variant?,
        using prompter: some Prompter,
        reportingTo reporter: Reporter
    ) throws -> PartialProjectConfiguration {
        do {
            return try InteractiveConfiguration().collect(name: name, variant: variant, using: prompter)
        } catch InteractivePromptError.cancelled {
            throw cancelled(using: prompter, reportingTo: reporter)
        } catch let InteractivePromptError.unresolvable(issue) {
            throw reporter.failure(.validationFailure, "The answers cannot be generated.", issues: [issue])
        }
    }

    private func destinationURL(for configuration: ProjectConfiguration) -> URL {
        URL(fileURLWithPath: destination ?? configuration.project.name).standardizedFileURL
    }
}
