import ArgumentParser
import Foundation
import ScaffoldCore
import ScaffoldSchema

/// Which project to work on. Shared by `init` and `plan`, because §11.1 makes
/// them two entrances to one implementation: a plan that took its input
/// differently would be a preview of something else.
struct ProjectOptions: ParsableArguments {
    @Argument(help: "The project name. Required with --preset; overrides project.name with --config.")
    var name: String?

    @Option(name: .customLong("config"), help: "Path to a scaffold.yml.")
    var configurationPath: String?

    @Option(name: .customLong("preset"), help: "A named set of defaults.")
    var preset: String?

    @Option(name: .customLong("destination"), help: "Where to create the project. Defaults to ./<name>.")
    var destination: String?
}

/// What a run would do, as opposed to what the project is. These shape the
/// plan, so `plan` has to accept them too or it would preview commands that
/// `init` is not going to run.
struct RunOptions: ParsableArguments {
    @Flag(name: .customLong("skip-git"), help: "Do not create a git repository.")
    var skipGit = false

    @Flag(name: .customLong("skip-generate"), help: "Do not run the generator.")
    var skipGenerate = false

    var generationOptions: GenerationOptions {
        GenerationOptions(initializeGit: !skipGit, runGenerator: !skipGenerate)
    }
}

extension ProjectOptions {
    func configuration(reportingTo reporter: Reporter) throws -> ProjectConfiguration {
        switch (configurationPath, preset) {
        case (nil, nil), (.some, .some):
            throw reporter.failure(.invalidArguments, "Pass exactly one of --config or --preset.")

        case let (path?, nil):
            var configuration = try readConfiguration(at: path, reportingTo: reporter)
            // A name on the command line wins: the user typed it last, and the
            // generated scaffold.yml records what was actually used.
            if let name {
                configuration.project.name = name
            }
            return configuration

        case let (nil, presetName?):
            return try configuration(fromPresetNamed: presetName, reportingTo: reporter)
        }
    }

    func destinationURL(for configuration: ProjectConfiguration) -> URL {
        // Standardised so that a path with `..` in it still yields the right
        // parent directory, which is where the staging area goes.
        URL(fileURLWithPath: destination ?? configuration.project.name).standardizedFileURL
    }

    private func configuration(
        fromPresetNamed presetName: String,
        reportingTo reporter: Reporter
    ) throws -> ProjectConfiguration {
        guard let preset = Preset.named(presetName) else {
            let known = Preset.all.map(\.name).joined(separator: ", ")
            throw reporter.failure(
                .invalidArguments,
                "There is no preset named '\(presetName)'. Try one of: \(known)."
            )
        }
        guard let name else {
            throw reporter.failure(
                .invalidArguments,
                "A preset does not name the project. Try: xscaffold init MyApp --preset \(presetName)"
            )
        }

        return preset.configuration(projectName: name)
    }
}
