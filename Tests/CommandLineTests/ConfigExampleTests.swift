import Foundation
import ScaffoldCore
import ScaffoldSchema
import Testing

/// Issue #96: `config example` from the outside — what lands on stdout, what a
/// shell can do with it, and what the envelope says. Run against the real
/// binary, because the promise is about a command someone types and redirects.
@Suite("The config example command")
struct ConfigExampleTests {
    /// The whole point of printing rather than writing: the shell decides where
    /// the file goes, and what it gets is a file `validate` accepts unedited.
    @Test("what it prints is a scaffold.yml validate accepts", arguments: Preset.allCases)
    func redirectsIntoAValidFile(preset: Preset) throws {
        try withTemporaryDirectory { root in
            let printed = try xscaffold("config", "example", "--preset", preset.rawValue)
            #expect(printed.exitStatus == 0)

            let path = root.appendingPathComponent("scaffold.yml")
            try printed.standardOutput.write(to: path, atomically: true, encoding: .utf8)

            let validated = try xscaffold("validate", path.path)
            #expect(validated.exitStatus == 0)
            #expect(validated.standardOutput.contains("is valid"))
        }
    }

    /// The other half of the ticket's second criterion, at the level a user
    /// meets it: generating from the example gets the project `--preset` would
    /// have got. Both sides go through the real binary, because a document that
    /// resolved differently on the way back in would still round-trip inside
    /// the library and only diverge here.
    @Test("generating from the example plans what the preset plans", arguments: Preset.allCases)
    func plansWhatThePresetPlans(preset: Preset) throws {
        try withTemporaryDirectory { root in
            let example = root.appendingPathComponent("example.yml")
            try xscaffold("config", "example", "--preset", preset.rawValue)
                .standardOutput.write(to: example, atomically: true, encoding: .utf8)

            // The same request, stated the short way: the preset by name, over
            // the identity an example cannot supply.
            let named = root.appendingPathComponent("named.yml")
            try """
            preset: \(preset.rawValue)
            project:
              name: \(Preset.placeholderName)
              bundleIdentifier: \(Preset.placeholderBundleIdentifier)
            interface:
              primary: swiftui
            """.write(to: named, atomically: true, encoding: .utf8)

            let fromExample = try decoded(run(["plan", "--config", example.path, "--output", "json"]))
            let fromPreset = try decoded(run(["plan", "--config", named.path, "--output", "json"]))

            #expect(fromExample.plan != nil)
            #expect(fromExample.plan == fromPreset.plan)
        }
    }

    /// The annotation has to open the file, or an editor will not pick up the
    /// schema — and stdout has to carry the document and nothing else, or the
    /// redirect produces YAML with a sentence in it.
    @Test("stdout is the document, starting with the schema annotation")
    func stdoutIsTheDocument() throws {
        let result = try xscaffold("config", "example", "--preset", "standard")

        #expect(result.standardOutput.hasPrefix("# yaml-language-server: $schema=https://"))
        #expect(result.standardOutput.contains("preset: standard\n"))
    }

    /// Resolved in full, not one `preset:` line: the ticket's reason for the
    /// command existing is that someone can read what they are about to
    /// generate and change it.
    @Test("the document is the preset resolved, not a line naming it")
    func resolvedInFull() throws {
        let result = try xscaffold("config", "example", "--preset", "production")

        #expect(result.standardOutput.contains("pattern: mvvm"), "the preset's architecture is spelled out")
        #expect(result.standardOutput.contains("name: staging"), "and its three environments")
        #expect(result.standardOutput.contains("enabled: true"), "and its UI tests")
        #expect(result.standardOutput.contains("languages:"), "and its localization")
    }

    /// Asking for no scale is an answer, not an omission: the schema's own
    /// defaults are where someone writing this file by hand starts.
    @Test("no preset prints the defaults, naming no preset")
    func withoutAPreset() throws {
        let result = try xscaffold("config", "example")

        #expect(result.exitStatus == 0)
        #expect(!result.standardOutput.contains("preset:"))
        #expect(result.standardOutput.contains("pattern: minimal"))
    }

    /// §11.3's envelope, and the command named as the pair — `example` alone
    /// would say nothing in a log of several runs.
    @Test("--output json is the usual envelope, carrying the configuration")
    func jsonEnvelope() throws {
        let result = try xscaffold("config", "example", "--preset", "minimal", "--output", "json")
        let output = try decoded(result)

        #expect(output.ok)
        #expect(output.command == "config example")
        #expect(output.exitCode == .success)
        #expect(output.resolvedConfiguration?.preset == .minimal)
        // The document belongs to text mode; JSON carries the value instead, so
        // stdout stays one parseable document.
        #expect(!result.standardOutput.contains("yaml-language-server"))
    }

    @Test("an unknown preset lists the ones that exist")
    func unknownPreset() throws {
        let result = try xscaffold("config", "example", "--preset", "enormous")

        #expect(result.exitStatus == ScaffoldExitCode.invalidArguments.rawValue)
        #expect(result.standardError.contains("There is no preset named 'enormous'"))
        #expect(result.standardError.contains("standard"))
    }

    /// The same mistake `new --preset` catches: a variant is not a scale, and
    /// the answer says where the platform and interface actually live in this
    /// command — in the document it prints.
    @Test("a variant name given to --preset says where platform and interface live")
    func variantNameGivenToPreset() throws {
        let result = try xscaffold("config", "example", "--preset", "ios-uikit")

        #expect(result.exitStatus == ScaffoldExitCode.invalidArguments.rawValue)
        #expect(result.standardError.contains("is a variant, not a preset"))
    }
}
