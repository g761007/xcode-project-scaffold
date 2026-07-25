import ArgumentParser
import ScaffoldCore
import ScaffoldSchema

/// Commands about `scaffold.yml` itself, as opposed to the project it
/// describes. A group rather than a top-level `example`, because §4.9 has more
/// than one thing to say about the file — `config schema` is the next — and a
/// scattering of file-shaped verbs at the top level would read as though each
/// were a stage of generation.
struct ConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Work with scaffold.yml itself.",
        subcommands: [ConfigExampleCommand.self]
    )
}

/// The non-interactive way to start a `scaffold.yml` (§4.9). `new`'s
/// "Save and Exit" covers the same need for someone at a terminal; this covers
/// it for someone at a pipe.
///
/// It prints rather than writes, so the shell decides where the file goes and
/// this command needs no destination rules of its own — nothing it does can
/// overwrite anything.
struct ConfigExampleCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "example",
        abstract: "Print an editable scaffold.yml to start from. Writes nothing.",
        discussion: """
          xscaffold config example > scaffold.yml
          xscaffold config example --preset standard > scaffold.yml

        The document is the preset resolved in full, not a single `preset:`
        line: an example exists to be read and edited, and a file that says
        only which scale it wants tells its reader nothing about what they are
        about to generate.

        The project identity in it is a placeholder — replace it, then
        `xscaffold validate scaffold.yml`.

        Available presets:
        \(Preset.allCases.map { "  \($0.rawValue)" }.joined(separator: "\n"))
        """
    )

    @Option(
        name: .customLong("preset"),
        help: "How much project to start with: \(Preset.allowedValues.joined(separator: ", ")).",
        completion: .list(Preset.allowedValues)
    )
    var presetName: String?

    @OptionGroup var output: OutputOptions

    /// The same refusal `new --preset` gives, including the pointer for the
    /// four platform combinations that hung off `--preset` until v0.4 — someone
    /// typing one here has made the same mistake and deserves the same answer.
    func validate() throws {
        guard let presetName, Preset(rawValue: presetName) == nil else { return }

        let known = Preset.allowedValues.joined(separator: ", ")
        guard Variant.named(presetName) == nil else {
            throw ValidationError("'\(presetName)' is a variant, not a preset. A variant picks the "
                + "platform and interface; edit those fields in the example. Presets: \(known).")
        }
        throw ValidationError("There is no preset named '\(presetName)'. Try one of: \(known).")
    }

    func run() throws {
        let reporter = Reporter(for: Self.self, under: ConfigCommand.self, format: output.format)
        let configuration: ProjectConfiguration
        let document: String

        do {
            // `validate()` has already refused anything that is not a preset,
            // so a nil here means none was asked for.
            configuration = try PresetResolution.baseConfiguration(
                for: presetName.flatMap(Preset.init(rawValue:))
            )
            document = try ScaffoldDocument().text(for: configuration)
        } catch {
            throw reporter.failure(.configurationParsingFailure, "\(error)")
        }

        // In text the document is the result, so stdout carries it and nothing
        // else — that is what makes `> scaffold.yml` produce a usable file. In
        // JSON the envelope carries the same configuration as a value, which is
        // what a caller that is not a shell wanted anyway (§11.3).
        reporter.succeed(
            CommandOutput(
                command: reporter.command,
                exitCode: .success,
                resolvedConfiguration: configuration
            ),
            text: document
        )
    }
}
