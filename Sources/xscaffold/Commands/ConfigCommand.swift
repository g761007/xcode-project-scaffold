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
          xscaffold config example --variant macos-appkit --preset production > scaffold.yml
          xscaffold config example --dependency-manager cocoapods > scaffold.yml

        The document is the preset resolved in full, not a single `preset:`
        line: an example exists to be read and edited, and a file that says
        only which scale it wants tells its reader nothing about what they are
        about to generate.

        The three flags are independent, exactly as they are on `new`: the
        variant picks the platform and interface, the preset picks how much
        project comes with them, and the dependency manager picks what reads
        the packages.

        The project identity in it is a placeholder — replace it, then
        `xscaffold validate scaffold.yml`.

        Available variants:
        \(Variant.all.map { "  \($0.name) — \($0.summary)" }.joined(separator: "\n"))

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

    @Option(
        name: .customLong("variant"),
        help: "A platform and interface combination; states both in the example."
    )
    var variantName: String?

    /// Worth a flag rather than "edit the one word", because the mode is not
    /// one word in the document: `production` with pods pins Bundler and a
    /// CocoaPods version during normalization (§17), and an example that did
    /// not show that would be hiding what the reader is about to generate —
    /// which is the whole reason this command prints a resolved document.
    @Option(
        name: .customLong("dependency-manager"),
        help: "What reads the packages: \(DependencyMode.allowedValues.joined(separator: ", "))."
    )
    var dependencyManagerName: String?

    @OptionGroup var output: OutputOptions

    /// Each flag is refused the way `new` refuses it, and for the same reason:
    /// a name that does not exist is worth answering with the ones that do,
    /// rather than with a document quietly built from a default.
    func validate() throws {
        try validatePreset()

        if let variantName, Variant.named(variantName) == nil {
            throw ValidationError("There is no variant named '\(variantName)'. Try one of: "
                + "\(Variant.all.map(\.name).joined(separator: ", ")).")
        }

        if let dependencyManagerName, DependencyMode(rawValue: dependencyManagerName) == nil {
            throw ValidationError("There is no dependency manager named '\(dependencyManagerName)'. "
                + "Try one of: \(DependencyMode.allowedValues.joined(separator: ", ")).")
        }
    }

    /// Includes the pointer for the four platform combinations that hung off
    /// `--preset` until v0.4 — someone typing one there has made the mistake
    /// that flag's history invites, and now has a `--variant` to be sent to.
    private func validatePreset() throws {
        guard let presetName, Preset(rawValue: presetName) == nil else { return }

        let known = Preset.allowedValues.joined(separator: ", ")
        guard Variant.named(presetName) == nil else {
            throw ValidationError("'\(presetName)' is a variant, not a preset. A variant picks the "
                + "platform and interface; pass it as --variant \(presetName). Presets: \(known).")
        }
        throw ValidationError("There is no preset named '\(presetName)'. Try one of: \(known).")
    }

    func run() throws {
        let reporter = Reporter(for: Self.self, under: ConfigCommand.self, format: output.format)
        let configuration: ProjectConfiguration
        let document: String

        do {
            // `validate()` has already refused every name that does not exist,
            // so a nil here means the flag was not given.
            configuration = try PresetResolution.baseConfiguration(
                for: presetName.flatMap(Preset.init(rawValue:)),
                variant: variantName.flatMap(Variant.named) ?? .iOSSwiftUI,
                dependencyMode: dependencyManagerName.flatMap(DependencyMode.init(rawValue:))
            )
            document = try ScaffoldDocument().text(for: configuration)
        } catch {
            throw reporter.failure(ScaffoldError(code: .configurationMalformed, message: "\(error)"))
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
