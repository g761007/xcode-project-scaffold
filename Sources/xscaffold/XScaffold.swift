import ArgumentParser
import ScaffoldSchema

@main
struct XScaffold: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "xscaffold",
        abstract: "Create a new Xcode project reproducibly, from a single version-controlled configuration file.",
        version: ScaffoldVersion.current,
        subcommands: [InitCommand.self]
    )
}
