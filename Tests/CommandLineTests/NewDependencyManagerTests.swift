import Foundation
import ScaffoldCore
import ScaffoldSchema
import Testing

/// The flag that decides how the generated project takes its dependencies
/// (#159). The mode is not one word in the document — `production` reading pods
/// pins Bundler and a CocoaPods version during normalization (ADR-0008) — so
/// the tests that matter are about whether the flag went through the document
/// path or was pasted on afterwards.
@Suite("The new command's dependency manager")
struct NewDependencyManagerTests {
    /// The sharpest assertion in the change: `new` authoring a configuration
    /// and `config example` printing one are two routes to the same document,
    /// and they must not disagree. If a future refactor sets the mode as a
    /// value rather than through the document, this is what notices — the
    /// Bundler pin only exists on the path that normalizes.
    @Test("the flag reaches the same document config example prints")
    func matchesConfigExample() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("Placeholder")
            try xscaffoldWithoutInput(
                "new", "Placeholder", "--variant", "ios-swiftui", "--preset", "production",
                "--dependency-manager", "cocoapods", "--destination", destination.path,
                "--yes", "--skip-git", "--skip-generate"
            )

            let authored = try String(
                contentsOf: destination.appendingPathComponent("scaffold.yml"), encoding: .utf8
            )
            let printed = try xscaffoldWithoutInput(
                "config", "example", "--preset", "production", "--dependency-manager", "cocoapods"
            ).standardOutput

            #expect(authored.trimmingCharacters(in: .whitespacesAndNewlines)
                == printed.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    /// Stated separately from the equivalence above, because that test would
    /// still pass if both routes lost the pin together.
    @Test("production reading pods pins Bundler and a CocoaPods version")
    func productionPinsBundler() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("Ledger")
            try xscaffoldWithoutInput(
                "new", "Ledger", "--variant", "ios-swiftui", "--preset", "production",
                "--dependency-manager", "cocoapods", "--destination", destination.path,
                "--yes", "--skip-git", "--skip-generate"
            )

            let authored = try String(
                contentsOf: destination.appendingPathComponent("scaffold.yml"), encoding: .utf8
            )

            #expect(authored.contains("mode: cocoapods"))
            #expect(authored.contains("enabled: true"))
            #expect(authored.contains("cocoapodsVersion:"))
        }
    }

    /// No preset is an answer rather than a missing one, so a stated mode has
    /// to work on its own. The normalization that pins Bundler belongs to
    /// `production`, and must not follow the mode around.
    @Test("the flag works with no preset, and brings no preset's extras with it")
    func flagWithoutPreset() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("Bare")
            try xscaffoldWithoutInput(
                "new", "Bare", "--variant", "ios-swiftui",
                "--dependency-manager", "cocoapods", "--destination", destination.path,
                "--yes", "--skip-git", "--skip-generate"
            )

            let authored = try String(
                contentsOf: destination.appendingPathComponent("scaffold.yml"), encoding: .utf8
            )

            #expect(authored.contains("mode: cocoapods"))
            #expect(!authored.contains("bundler:"))
        }
    }

    /// The regression guard for the whole change: a run that does not mention
    /// the flag has to produce what it produced before the flag existed.
    @Test("an omitted flag leaves the preset's own mode alone", arguments: [
        ("minimal", "mode: none"), ("standard", "mode: spm"), ("production", "mode: spm")
    ])
    func omittedFlagChangesNothing(preset: String, expected: String) throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("Untouched")
            try xscaffoldWithoutInput(
                "new", "Untouched", "--variant", "ios-swiftui", "--preset", preset,
                "--destination", destination.path, "--yes", "--skip-git", "--skip-generate"
            )

            let authored = try String(
                contentsOf: destination.appendingPathComponent("scaffold.yml"), encoding: .utf8
            )

            #expect(authored.contains(expected))
        }
    }

    @Test("an unknown dependency manager is refused with the list of real ones")
    func unknownDependencyManager() throws {
        let result = try xscaffoldWithoutInput(
            "new", "App", "--variant", "ios-swiftui", "--dependency-manager", "carthage", "--yes"
        )

        #expect(result.exitStatus == ScaffoldExitCode.invalidArguments.rawValue)
        #expect(result.standardError.contains("There is no dependency manager named 'carthage'"))
        for name in ["none", "spm", "cocoapods", "mixed"] {
            #expect(result.standardError.contains(name))
        }
    }

    /// Refused before anything is written, like every other bad flag value:
    /// the check lives in `validate()`, which runs before `run()`.
    @Test("a bad mode is refused before the destination is touched")
    func badModeWritesNothing() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("Never")
            _ = try xscaffoldWithoutInput(
                "new", "Never", "--variant", "ios-swiftui", "--dependency-manager", "carthage",
                "--destination", destination.path, "--yes", "--skip-git", "--skip-generate"
            )

            #expect(!FileManager.default.fileExists(atPath: destination.path))
        }
    }
}
