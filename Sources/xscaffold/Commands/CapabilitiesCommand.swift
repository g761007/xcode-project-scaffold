import ArgumentParser
import ScaffoldCore
import ScaffoldSchema

/// The agent's first stop (§19): what can this binary generate, as data. Text
/// for a person skimming; the JSON document is the real interface.
struct CapabilitiesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "capabilities",
        abstract: "Show what this version can generate. Writes nothing."
    )

    @OptionGroup var output: OutputOptions

    func run() throws {
        let reporter = Reporter(for: Self.self, format: output.format)
        let capabilities = CapabilitiesDocument.current(version: ScaffoldVersion.current)

        reporter.succeed(
            CommandOutput(command: reporter.command, exitCode: .success, capabilities: capabilities),
            text: text(for: capabilities)
        )
    }

    private func text(for capabilities: CapabilitiesDocument) -> String {
        func line(_ label: String, _ values: [String]) -> String {
            "\(label): \(values.joined(separator: ", "))"
        }

        return [
            "xscaffold \(capabilities.version)",
            line("schema versions", capabilities.schemaVersions.map(String.init)),
            line("variants", capabilities.variants),
            line("platforms", capabilities.platforms),
            line("architectures", capabilities.architectures),
            line("dependency modes", capabilities.dependencyManagementModes),
            line("test frameworks", capabilities.testingFrameworks),
            line("features", capabilities.features)
        ].joined(separator: "\n")
    }
}
