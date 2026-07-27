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
          xscaffold new MyApp --variant ios-swiftui --preset standard --yes

        A variant picks the platform and interface; a preset picks how much
        project comes with them. They are independent, and both are optional.

        Available presets:
        \(Preset.allCases.map { "  \($0.rawValue)" }.joined(separator: "\n"))

        Available variants:
        \(Variant.all.map { "  \($0.name.padding(toLength: 14, withPad: " ", startingAt: 0))\($0.summary)" }
            .joined(separator: "\n"))
        """
    )

    @Argument(help: "The project name. Asked for if omitted.")
    var name: String?

    @Option(
        name: .customLong("destination"),
        help: "Where to create the project. Defaults to ./<name>.",
        completion: .directory
    )
    var destination: String?

    @Option(
        name: .customLong("variant"),
        help: "A platform and interface combination; answers those two questions.",
        completion: .list(Variant.all.map(\.name))
    )
    var variantName: String?

    /// Back as a scale rather than as a platform combination (§17). Between
    /// v0.4 and v0.6 this flag existed only to point at `--variant`; that
    /// pointer is gone, because a flag that now works must not answer as
    /// though it does not.
    @Option(
        name: .customLong("preset"),
        help: "How much project to create: \(Preset.allowedValues.joined(separator: ", ")).",
        completion: .list(Preset.allowedValues)
    )
    var presetName: String?

    /// The flag `config example` already takes, named and valued identically
    /// so that one vocabulary covers both. It is worth a flag rather than "edit
    /// the one word afterwards" for the reason that command gives: the mode is
    /// not one word in the document — `production` reading pods pins Bundler
    /// and a CocoaPods version during normalization (ADR-0008) — so it is
    /// stated where the preset can still normalize around it.
    ///
    /// It is also the only way a `--yes` run reaches a mode its preset does not
    /// supply, which is the run CI makes.
    @Option(
        name: .customLong("dependency-manager"),
        help: "What reads the packages: \(DependencyMode.allowedValues.joined(separator: ", ")).",
        completion: .list(DependencyMode.allowedValues)
    )
    var dependencyManagerName: String?

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

    @Flag(name: .customLong("advanced"), help: "Also ask about the fields most projects leave at their defaults.")
    var advanced = false

    @Flag(name: .customLong("open"), help: "Open the generated project when generation succeeds.")
    var openWhenDone = false

    /// `new` is interactive by definition, so the machine-readable path is out:
    /// json forbids interaction (§11.3). The build-flag contradiction
    /// `generate` catches applies here too, and `--open` joins it for the same
    /// reason: skipping the generator leaves no project file to act on.
    func validate() throws {
        if let presetName, Preset(rawValue: presetName) == nil {
            let known = Preset.allowedValues.joined(separator: ", ")
            // The four platform combinations hung off --preset until v0.4.
            // The flag works again now, so it can no longer refuse outright —
            // but someone typing the old value still deserves the pointer it
            // used to give, rather than a list that does not contain what they
            // meant.
            guard Variant.named(presetName) == nil else {
                throw ValidationError("'\(presetName)' is a variant, not a preset. Try "
                    + "--variant \(presetName), or a preset: \(known).")
            }
            throw ValidationError("There is no preset named '\(presetName)'. Try one of: \(known).")
        }
        if let variantName, Variant.named(variantName) == nil {
            let known = Variant.all.map(\.name).joined(separator: ", ")
            throw ValidationError("There is no variant named '\(variantName)'. Try one of: \(known).")
        }
        if let dependencyManagerName, DependencyMode(rawValue: dependencyManagerName) == nil {
            throw ValidationError("There is no dependency manager named '\(dependencyManagerName)'. "
                + "Try one of: \(DependencyMode.allowedValues.joined(separator: ", ")).")
        }
        guard output.format != .json else {
            throw ValidationError("--output json is not available for new, which is interactive. "
                + "Use generate --config <file> for a machine-readable run.")
        }
        guard !validateBuild || !runOptions.skipGenerate else {
            throw ValidationError("--validate-build cannot be used with --skip-generate: there would be "
                + "no project file to build.")
        }
        guard !openWhenDone || !runOptions.skipGenerate else {
            throw ValidationError("--open cannot be used with --skip-generate: there would be "
                + "no project file to open.")
        }
    }

    /// The preset the flags name. `validate()` has already refused anything
    /// that is not one, so a nil here means none was given.
    private var preset: Preset? {
        presetName.flatMap(Preset.init(rawValue:))
    }

    /// The dependency mode the flags name, on the same terms.
    private var dependencyMode: DependencyMode? {
        dependencyManagerName.flatMap(DependencyMode.init(rawValue:))
    }

    /// What the stated preset resolves to, before a single question is asked:
    /// the bases the interactive answers are laid over, one per dependency mode
    /// because that answer chooses between them.
    ///
    /// Empty when no preset was named, which asks for the schema's own defaults
    /// — what `resolved()` applies with no base at all.
    ///
    /// One resolution per run, rather than the three this command used to do.
    /// The document path is where a mode is normalized into a preset, and three
    /// separate trips through it are three chances for one of them to be given
    /// different arguments and come out different.
    private func resolvedPresetBases() throws -> PresetBases {
        try PresetBases(preset: preset, variant: variantName.flatMap(Variant.named) ?? .iOSSwiftUI)
    }

    func run() throws {
        let reporter = Reporter(for: Self.self, format: .text)
        let prompter = SystemPrompter()
        let variant = variantName.flatMap(Variant.named)
        // Resolved once, here, so the interactive loop stays a pure overlay.
        let presetBases = try resolvedPresetBases()

        // --yes answered the menu in advance: no preview stop, straight to
        // generation once the answers exist. The summary still shows — the
        // flag skips questions, never information (§4.2).
        if assumeYes {
            return try generateWithoutPreview(
                variant: variant, presetBases: presetBases, using: prompter, reportingTo: reporter
            )
        }

        guard prompter.isInteractive else {
            throw reporter.failure(ScaffoldError(
                code: .invalidArguments,
                message: "new needs a terminal to ask its questions. For a non-interactive run, use "
                    + "generate --config <file>, or new <name> --variant <name> --yes."
            ))
        }
        let answers = try collect(
            variant: variant, presetBases: presetBases, using: prompter, reportingTo: reporter
        )

        // The preview loop (§4.2): resolve, validate, plan, preview, menu —
        // and around again after every edit. A generation failure maps to the
        // code it chose, the same mapping `writePlan` performs.
        let outcome = try mappingGenerationFailure(reportingTo: reporter) {
            do {
                return try PreviewSession(force: force, presetBases: presetBases).run(
                    answers: answers,
                    destination: { destinationURL(for: $0) },
                    makePlan: { try makePlan(for: $0, options: runOptions.generationOptions,
                                             reportingTo: reporter) },
                    using: prompter
                )
            } catch let InteractivePromptError.unresolvable(issue) {
                throw reporter.failure(
                    ScaffoldError(code: .configurationInvalid, message: "The answers cannot be generated."),
                    issues: [issue]
                )
            }
        }

        switch outcome {
        case let .generated(validated, plan, warnings, destination):
            try finishGeneration(plan, warnings: warnings, for: validated.configuration,
                                 at: destination, reportingTo: reporter)

        case let .savedManifest(manifest):
            reportSaved(manifest, at: manifest.deletingLastPathComponent(), to: reporter)

        case .cancelled:
            throw cancelled(using: prompter, reportingTo: reporter)
        }
    }
}

extension NewCommand {
    /// The whole `--yes` run: the same resolve, validate, plan and write the
    /// preview loop performs, with the menu already answered. It is its own
    /// path rather than a branch of the loop because there is no loop — nothing
    /// here can send the run back to a question.
    private func generateWithoutPreview(
        variant: Variant?,
        presetBases: PresetBases,
        using prompter: some Prompter,
        reportingTo reporter: Reporter
    ) throws {
        let configuration = try assumedConfiguration(
            variant: variant, presetBases: presetBases, using: prompter, reportingTo: reporter
        )
        let (validated, warnings) = try checkConfiguration(
            configuration, describedAs: "The answers", reportingTo: reporter
        )
        let plan = try makePlan(for: validated, options: runOptions.generationOptions, reportingTo: reporter)
        let destination = destinationURL(for: configuration)

        _ = confirmed(plan, at: destination, using: prompter, assumeYes: true)
        // The preview says this before the menu; this path has no menu, and
        // `--yes` skips questions rather than information (§4.2). It is also
        // the path CI takes, which is where the tools are most likely absent.
        for missing in EnvironmentDoctor().missingTools(calledBy: plan, for: configuration) {
            reporter.note("Warning: \(missing.warningLine)")
        }
        try writePlan(plan, to: destination, force: force, for: configuration, reportingTo: reporter)
        try finishGeneration(plan, warnings: warnings, for: configuration,
                             at: destination, reportingTo: reporter)
    }

    /// The configuration a `--yes` run generates from: the one-line
    /// variant-and-name path (no terminal needed, none consulted), or the
    /// questions as usual with only the menu pre-answered.
    private func assumedConfiguration(
        variant: Variant?,
        presetBases: PresetBases,
        using prompter: some Prompter,
        reportingTo reporter: Reporter
    ) throws -> ProjectConfiguration {
        if let variant {
            guard let name else {
                throw reporter.failure(ScaffoldError(
                    code: .invalidArguments,
                    message: "A variant does not name the project. "
                        + "Try: xscaffold new MyApp --variant \(variant.name) --yes"
                ))
            }
            // Not the base above: that one has a placeholder identity and this
            // path has a real name, so the document is built once with both.
            return try variant.configuration(
                projectName: name, preset: preset, dependencyMode: dependencyMode
            )
        }

        guard prompter.isInteractive else {
            throw reporter.failure(ScaffoldError(
                code: .invalidArguments,
                message: "new needs a terminal to ask its questions. For a non-interactive run, use "
                    + "generate --config <file>, or new <name> --variant <name> --yes."
            ))
        }
        return try presetBases.configuration(
            for: collect(variant: nil, presetBases: presetBases, using: prompter, reportingTo: reporter)
        )
    }

    /// Everything after the files are down, shared by the --yes path and the
    /// menu's Generate: the build check if asked for, the created report, and
    /// then --open — last, because a failure to open is a note on a success,
    /// not a failure of the run (the project is there either way).
    private func finishGeneration(
        _ plan: GenerationPlan,
        warnings: [ValidationIssue],
        for configuration: ProjectConfiguration,
        at destination: URL,
        reportingTo reporter: Reporter
    ) throws {
        if validateBuild {
            try verifyBuild(of: configuration, at: destination, reportingTo: reporter)
        }
        reportCreated(plan, warnings: warnings, for: configuration, at: destination, to: reporter)

        if openWhenDone {
            do {
                try ProjectOpener().open(configuration, at: destination)
            } catch {
                reporter.note("\(error)")
            }
        }
    }

    private func collect(
        variant: Variant?,
        presetBases: PresetBases,
        using prompter: some Prompter,
        reportingTo reporter: Reporter
    ) throws -> PartialProjectConfiguration {
        do {
            return try InteractiveConfiguration(presetBases: presetBases)
                .collect(
                    name: name, variant: variant, dependencyMode: dependencyMode,
                    advanced: advanced, using: prompter
                )
        } catch InteractivePromptError.cancelled {
            throw cancelled(using: prompter, reportingTo: reporter)
        } catch let InteractivePromptError.unresolvable(issue) {
            throw reporter.failure(
                ScaffoldError(code: .configurationInvalid, message: "The answers cannot be generated."),
                issues: [issue]
            )
        }
    }

    /// Save-and-exit's report: where the manifest is, and steps that work as
    /// written — in-place generation needs `--destination .`, because
    /// `generate` otherwise defaults to creating `./<name>` inside the
    /// directory the user just changed into.
    private func reportSaved(_ manifest: URL, at destination: URL, to reporter: Reporter) {
        reporter.succeed(
            CommandOutput(command: reporter.command, exitCode: .success, destination: destination.path),
            text: """
            Saved \(manifest.path); nothing else was created.

            Next steps:
              cd \(destination.path)
              xscaffold plan --config scaffold.yml --destination .
              xscaffold generate --destination .
            """
        )
    }

    private func destinationURL(for configuration: ProjectConfiguration) -> URL {
        URL(fileURLWithPath: destination ?? configuration.project.name).standardizedFileURL
    }
}
