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

    /// The same mistake `new --preset` catches: a variant is not a scale. Now
    /// that this command has a `--variant` of its own, the answer names it.
    @Test("a variant name given to --preset points at --variant")
    func variantNameGivenToPreset() throws {
        let result = try xscaffold("config", "example", "--preset", "ios-uikit")

        #expect(result.exitStatus == ScaffoldExitCode.invalidArguments.rawValue)
        #expect(result.standardError.contains("is a variant, not a preset"))
        #expect(result.standardError.contains("--variant ios-uikit"))
    }
}

/// Issue #103: the other two flags §4.9 gives this command. A variant and a
/// preset are independent axes on `new`; they have to be independent here too,
/// or the same two words mean different things depending on which command they
/// are typed after.
@Suite("The example states what the flags say")
struct ConfigExampleFlagTests {
    @Test("a variant states its platform and its interface", arguments: Variant.all)
    func variantIsStated(variant: Variant) throws {
        let printed = try xscaffold("config", "example", "--variant", variant.name)
        let output = try decoded(
            run(["config", "example", "--variant", variant.name, "--output", "json"])
        )
        let configuration = try #require(output.resolvedConfiguration)

        #expect(printed.exitStatus == 0)
        #expect(configuration.product.platform.rawValue == (variant.name.hasPrefix("ios") ? "ios" : "macos"))
        #expect(printed.standardOutput.contains("platform: \(configuration.product.platform.rawValue)"))
        #expect(printed.standardOutput.contains("primary: \(configuration.interface.primary.rawValue)"))
    }

    /// The lifecycle follows from the interface rather than being asked for, so
    /// an AppKit example that still said `swiftui` would be one the reader has
    /// to correct before it generates.
    @Test("a variant brings what follows from it")
    func variantBringsItsLifecycle() throws {
        let result = try xscaffold("config", "example", "--variant", "macos-appkit")

        #expect(result.standardOutput.contains("primary: appkit"))
        #expect(result.standardOutput.contains("lifecycle: app-delegate"))
    }

    /// Orthogonal, the way #34 promised for `new`: the variant decides the two
    /// interface fields and the preset decides everything else, and neither
    /// overwrites the other.
    @Test("a variant and a preset compose")
    func variantComposesWithPreset() throws {
        let result = try xscaffold(
            "config", "example", "--variant", "macos-appkit", "--preset", "production"
        )

        #expect(result.standardOutput.contains("platform: macos"))
        #expect(result.standardOutput.contains("primary: appkit"))
        #expect(result.standardOutput.contains("preset: production"))
        #expect(result.standardOutput.contains("name: staging"), "the preset's third environment")
    }

    /// The reason this flag exists rather than "edit the one word": under
    /// `production`, choosing pods pins Bundler and a CocoaPods version during
    /// normalization. An example that showed only `mode: cocoapods` would be
    /// hiding two fields the reader is about to generate.
    @Test("a dependency manager brings what normalization adds to it")
    func dependencyManagerIsResolvedInFull() throws {
        let result = try xscaffold(
            "config", "example", "--preset", "production", "--dependency-manager", "cocoapods"
        )

        #expect(result.standardOutput.contains("mode: cocoapods"))
        #expect(result.standardOutput.contains("bundler:"))
        #expect(result.standardOutput.contains("cocoapodsVersion:"))
    }

    /// Unstated is not the same as stated-to-the-same-value: without the flag
    /// the mode is the preset's to choose, and `standard` chooses SPM.
    @Test("no dependency manager leaves the preset's own")
    func dependencyManagerDefaultsToThePreset() throws {
        let result = try xscaffold("config", "example", "--preset", "standard")

        #expect(result.standardOutput.contains("mode: spm"))
    }

    @Test("every combination prints a document validate accepts")
    func everyCombinationValidates() throws {
        try withTemporaryDirectory { root in
            for variant in Variant.all {
                for preset in Preset.allCases {
                    for mode in DependencyMode.allCases {
                        let printed = try run([
                            "config", "example",
                            "--variant", variant.name,
                            "--preset", preset.rawValue,
                            "--dependency-manager", mode.rawValue
                        ])
                        let path = root.appendingPathComponent("scaffold.yml")
                        try printed.standardOutput.write(to: path, atomically: true, encoding: .utf8)

                        let validated = try run(["validate", path.path])
                        #expect(
                            validated.exitStatus == 0,
                            "\(variant.name) \(preset.rawValue) \(mode.rawValue): \(validated.standardError)"
                        )
                    }
                }
            }
        }
    }

    @Test("an unknown variant lists the ones that exist")
    func unknownVariant() throws {
        let result = try xscaffold("config", "example", "--variant", "ios-appkit")

        #expect(result.exitStatus == ScaffoldExitCode.invalidArguments.rawValue)
        #expect(result.standardError.contains("There is no variant named 'ios-appkit'"))
        #expect(result.standardError.contains("macos-appkit"))
    }

    @Test("an unknown dependency manager lists the ones that exist")
    func unknownDependencyManager() throws {
        let result = try xscaffold("config", "example", "--dependency-manager", "carthage")

        #expect(result.exitStatus == ScaffoldExitCode.invalidArguments.rawValue)
        #expect(result.standardError.contains("There is no dependency manager named 'carthage'"))
        #expect(result.standardError.contains("cocoapods"))
    }
}
