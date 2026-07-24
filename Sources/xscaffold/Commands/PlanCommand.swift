import ArgumentParser
import ScaffoldCore
import ScaffoldSchema

/// Shows what `init` would do. §11.1 makes this and `init --dry-run` two names
/// for one thing, so both call `reportPlan`: a preview that could disagree with
/// the run it previews would be worse than no preview.
struct PlanCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "plan",
        abstract: "Show what init would create. Writes nothing."
    )

    @OptionGroup var project: ProjectOptions
    @OptionGroup var runOptions: RunOptions
    @OptionGroup var output: OutputOptions

    @Flag(name: .customLong("files"), help: "List every file and command in the plan.")
    var listFiles = false

    @Flag(name: .customLong("resolved-config"), help: "Show the configuration with every default resolved.")
    var showResolvedConfiguration = false

    func run() throws {
        try reportPlan(
            for: project,
            run: runOptions,
            listingFiles: listFiles,
            showingResolvedConfiguration: showResolvedConfiguration,
            to: Reporter(for: Self.self, format: output.format)
        )
    }
}
