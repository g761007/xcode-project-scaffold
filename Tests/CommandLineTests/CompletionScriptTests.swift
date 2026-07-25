import Foundation
import ScaffoldCore
import ScaffoldSchema
import Testing

/// A shell xscaffold generates completions for, and the flag that checks a
/// script for syntax without running it. `-n` is what makes the check worth
/// running: a script with an unbalanced quote is caught here rather than by
/// whoever sources it.
private struct Shell: Sendable {
    let name: String
    let syntaxCheckFlag: String

    static let zsh = Shell(name: "zsh", syntaxCheckFlag: "-n")
    static let bash = Shell(name: "bash", syntaxCheckFlag: "-n")
    static let fish = Shell(name: "fish", syntaxCheckFlag: "--no-execute")

    /// Where the shell is, if it is installed at all. fish is not on a stock
    /// macOS, so its check is skipped rather than failed — a red test on a
    /// machine without fish would say nothing about the script.
    var path: String? {
        let result = try? SystemProcessRunner().run(ProcessInvocation(
            executable: "/usr/bin/which",
            arguments: [name],
            workingDirectory: FileManager.default.temporaryDirectory
        ))
        guard result?.succeeded == true else { return nil }
        return result?.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private func assertScriptParses(in shell: Shell) throws {
    let shellPath = try #require(shell.path)

    try withTemporaryDirectory { root in
        let script = root.appendingPathComponent("xscaffold-completion")
        try xscaffold("--generate-completion-script", shell.name).standardOutput
            .write(to: script, atomically: true, encoding: .utf8)

        let result = try SystemProcessRunner().run(ProcessInvocation(
            executable: shellPath,
            arguments: [shell.syntaxCheckFlag, script.path],
            workingDirectory: root
        ))

        #expect(result.succeeded, "\(shell.name): \(result.combinedOutput)")
    }
}

/// A completion that lists values a user would otherwise have to remember has
/// to list the real ones. Everything here is checked against the schema's own
/// values, so a fifth variant with no completion for it is a test failure
/// rather than a user typing the name in full for the next six months.
@Suite("Completion scripts")
struct CompletionScriptTests {
    @Test("every shell gets a script", arguments: ["zsh", "bash", "fish"])
    func scriptIsProduced(shell: String) throws {
        let result = try xscaffold("--generate-completion-script", shell)

        #expect(result.exitStatus == 0)
        #expect(result.standardOutput.count > 500)
    }

    @Test("the variants offered are the variants that exist", arguments: ["zsh", "bash", "fish"])
    func variantsAreComplete(shell: String) throws {
        let script = try xscaffold("--generate-completion-script", shell).standardOutput

        for variant in Variant.all {
            #expect(script.contains(variant.name), "\(shell): \(variant.name)")
        }
    }

    @Test("the presets offered are the presets that exist", arguments: ["zsh", "bash", "fish"])
    func presetsAreComplete(shell: String) throws {
        let script = try xscaffold("--generate-completion-script", shell).standardOutput

        for preset in Preset.allowedValues {
            #expect(script.contains(preset), "\(shell): \(preset)")
        }
    }

    /// A configuration is a file the user already has, so the completion offers
    /// files rather than nothing — and both spellings of the extension, since
    /// `--config` has always taken any path.
    @Test("a configuration path completes to YAML files")
    func configurationPathCompletesToFiles() throws {
        let script = try xscaffold("--generate-completion-script", "zsh").standardOutput

        #expect(script.contains("*.yml *.yaml"))
    }

    @Test("the zsh script parses", .enabled(if: Shell.zsh.path != nil))
    func zshParses() throws {
        try assertScriptParses(in: .zsh)
    }

    @Test("the bash script parses", .enabled(if: Shell.bash.path != nil))
    func bashParses() throws {
        try assertScriptParses(in: .bash)
    }

    /// Reported as skipped, not passed, where fish is not installed.
    @Test("the fish script parses", .enabled(if: Shell.fish.path != nil))
    func fishParses() throws {
        try assertScriptParses(in: .fish)
    }
}
