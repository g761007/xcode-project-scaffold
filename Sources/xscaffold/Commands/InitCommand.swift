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

    @Argument(help: "The project name. Required with --preset; overrides project.name with --config.")
    var name: String?

    @Option(name: .customLong("config"), help: "Path to a scaffold.yml.")
    var configurationPath: String?

    @Option(name: .customLong("preset"), help: "A named set of defaults.")
    var preset: String?

    @Option(name: .customLong("destination"), help: "Where to create the project. Defaults to ./<name>.")
    var destination: String?

    @Flag(name: .customLong("force"), help: "Write into a destination that is not empty.")
    var force = false

    @Flag(name: .customLong("skip-git"), help: "Do not create a git repository.")
    var skipGit = false

    @Flag(name: .customLong("skip-generate"), help: "Do not run the generator.")
    var skipGenerate = false

    func run() throws {
        let configuration = try loadConfiguration()
        try reportValidation(of: configuration)

        let plan = try makePlan(for: configuration)
        // Standardised so that a path with `..` in it still yields the right
        // parent directory, which is where the staging area goes.
        let target = URL(fileURLWithPath: destination ?? configuration.project.name).standardizedFileURL

        try write(plan, to: target)
        report(plan, for: configuration, at: target)
    }
}

// MARK: - Where the configuration comes from

extension InitCommand {
    private func loadConfiguration() throws -> ProjectConfiguration {
        switch (configurationPath, preset) {
        case (nil, nil), (.some, .some):
            throw failure(.invalidArguments, "Pass exactly one of --config or --preset.")

        case let (path?, nil):
            return try configuration(fromFileAt: path)

        case let (nil, presetName?):
            return try configuration(fromPresetNamed: presetName)
        }
    }

    private func configuration(fromFileAt path: String) throws -> ProjectConfiguration {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            throw failure(.configurationParsingFailure, "Cannot read '\(path)'.")
        }

        do {
            var configuration = try ConfigurationCoder().decode(text)
            // A name on the command line wins: the user typed it last, and the
            // generated scaffold.yml records what was actually used.
            if let name {
                configuration.project.name = name
            }
            return configuration
        } catch {
            throw failure(.configurationParsingFailure, "\(path): \(error)")
        }
    }

    private func configuration(fromPresetNamed presetName: String) throws -> ProjectConfiguration {
        guard let preset = Preset.named(presetName) else {
            let known = Preset.all.map(\.name).joined(separator: ", ")
            throw failure(.invalidArguments, "There is no preset named '\(presetName)'. Try one of: \(known).")
        }
        guard let name else {
            throw failure(
                .invalidArguments,
                "A preset does not name the project. Try: xscaffold init MyApp --preset \(presetName)"
            )
        }

        return preset.configuration(projectName: name)
    }
}

// MARK: - Refusing to generate

extension InitCommand {
    private func reportValidation(of configuration: ProjectConfiguration) throws {
        let issues = ConfigurationValidator().validate(configuration)
        guard !issues.isEmpty else { return }

        for issue in issues {
            printToStandardError(describe(issue))
        }
        guard !issues.contains(where: { $0.severity == .error }) else {
            throw failure(.validationFailure, "The configuration cannot be generated.")
        }
    }

    private func describe(_ issue: ValidationIssue) -> String {
        var lines = ["\(issue.code.rawValue)  \(issue.path ?? "scaffold.yml")"]
        lines.append("    \(issue.message)")
        if let suggestion = issue.suggestion {
            lines.append("    \(suggestion)")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Generating

extension InitCommand {
    private func makePlan(for configuration: ProjectConfiguration) throws -> GenerationPlan {
        let options = GenerationOptions(initializeGit: !skipGit, runGenerator: !skipGenerate)

        do {
            return try GenerationPlanBuilder().makePlan(for: configuration, options: options)
        } catch {
            throw failure(.templateResolutionFailure, "\(error)")
        }
    }

    private func write(_ plan: GenerationPlan, to destination: URL) throws {
        do {
            try PlanExecutor().execute(plan, at: destination, force: force)
        } catch let error as GenerationError {
            throw failure(exitCode(for: error), "\(error)")
        } catch {
            throw failure(.generationFailure, "\(error)")
        }
    }

    private func exitCode(for error: GenerationError) -> ScaffoldExitCode {
        switch error {
        case .destinationNotEmpty, .destinationIsNotADirectory, .cannotReplaceDirectory: .fileConflict
        case .executableNotFound: .environmentRequirementMissing
        case .commandFailed: .externalCommandFailure
        case .unsafePlannedPath: .generationFailure
        // What could not be undone does not change why it failed.
        case let .failedLeavingFiles(underlying, _): exitCode(for: underlying)
        }
    }
}

// MARK: - Saying what happened

extension InitCommand {
    private func report(_ plan: GenerationPlan, for configuration: ProjectConfiguration, at destination: URL) {
        print("Created \(configuration.project.name) at \(destination.path)")
        print("  \(plan.files.count) files")
        for command in plan.commands {
            print("  \(command.displayString)")
        }

        print("")
        guard !skipGenerate else {
            // Deliberately not "run `make generate`": which recipe produces the
            // project file is the generated Makefile's business, and the README
            // that has just been written says so.
            print("There is no project file yet. The generated README.md says how to produce one.")
            return
        }
        print("Open it with:\n  open \(destination.appendingPathComponent(configuration.projectFileName).path)")
    }
}
