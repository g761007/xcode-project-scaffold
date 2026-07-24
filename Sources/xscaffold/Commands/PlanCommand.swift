import ArgumentParser
import Foundation
import ScaffoldCore
import ScaffoldSchema

/// Shows what `generate` would do. §11.1 makes them two entrances to one
/// implementation, so a preview cannot disagree with the run it previews.
struct PlanCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "plan",
        abstract: "Show what generate would create. Writes nothing."
    )

    @Option(name: .customLong("config"), help: "Path to a scaffold.yml. Defaults to ./scaffold.yml.")
    var configurationPath: String = "scaffold.yml"

    @Option(name: .customLong("destination"), help: "Where the project would go. Defaults to ./<name>.")
    var destination: String?

    @OptionGroup var runOptions: RunOptions
    @OptionGroup var output: OutputOptions

    @Flag(name: .customLong("files"), help: "List every file and command in the plan.")
    var listFiles = false

    @Flag(name: .customLong("resolved-config"), help: "Show the configuration with every default resolved.")
    var showResolvedConfiguration = false

    func run() throws {
        try reportPlan(
            configurationAt: configurationPath,
            destination: destination,
            run: runOptions,
            listingFiles: listFiles,
            showingResolvedConfiguration: showResolvedConfiguration,
            to: Reporter(for: Self.self, format: output.format)
        )
    }
}
