import Foundation
import ScaffoldCore
import ScaffoldSchema
import Testing

private let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent() // CommandLineTests
    .deletingLastPathComponent() // Tests
    .deletingLastPathComponent() // repository root

private let skillPath = repositoryRoot.appendingPathComponent("Skills/xcode-project-scaffold/SKILL.md")

/// Everything that tells someone — or something — what to type: the Skill an
/// agent executes, the README, and every page under `docs/`. Discovered rather
/// than listed, so a document added without a test is not a thing that can
/// happen.
private let documentation: [URL] = {
    let manager = FileManager.default
    var found = [skillPath, repositoryRoot.appendingPathComponent("README.md")]

    for directory in ["docs", "examples"] {
        let url = repositoryRoot.appendingPathComponent(directory)
        let contents = (try? manager.contentsOfDirectory(atPath: url.path)) ?? []
        found += contents.filter { $0.hasSuffix(".md") }.sorted().map(url.appendingPathComponent)
    }
    return found.filter { manager.fileExists(atPath: $0.path) }
}()

/// A flag the binary accepts and its help does not list. ArgumentParser hides
/// this one, and the documentation is right to mention it.
private let hiddenFlags = ["--generate-completion-script"]

/// Where a shell takes over: everything from here on belongs to the shell, not
/// to xscaffold, and the command in front of it is still whole.
private let shellBoundaries: Set<String> = [">", ">>", "|", "\\", "#"]

/// One `xscaffold …` line the documentation tells a reader to run.
struct SkillCommand: CustomStringConvertible, Sendable {
    /// The subcommand path: `["config", "example"]`, or empty for the root.
    let path: [String]
    let flags: [String]
    /// Everything after `xscaffold`, up to a shell boundary — what would be
    /// passed as argv.
    let arguments: [String]
    /// Whether the whole line was read. A line that ends in a `<placeholder>`
    /// is documentation of a shape rather than a command to run.
    let isComplete: Bool
    let description: String

    /// Commands that cannot write anything, and can therefore be run to see
    /// whether the line as documented is one the binary accepts.
    var isReadOnly: Bool {
        guard let verb = path.first else { return false }
        return ["validate", "plan", "doctor", "capabilities", "config"].contains(verb)
    }
}

/// Every `xscaffold …` in the documentation, wherever it appears — a fenced
/// block, a numbered step, or the middle of a sentence. Anything a reader could
/// copy is something that has to work.
let skillCommands: [SkillCommand] = documentation.flatMap(commands(in:))

private func commands(in file: URL) -> [SkillCommand] {
    guard let text = try? String(contentsOf: file, encoding: .utf8) else { return [] }
    let name = file.lastPathComponent

    // Line-bounded, and on a word boundary: `\s` would run the match past the
    // end of a line and swallow the next one, and a bare `xscaffold` matches
    // inside `_xscaffold` in a completions path.
    return text.matches(of: /\bxscaffold((?:[^\S\n]+[^\s`\n]+)*)/).compactMap { match in
        let tokens = match.output.1.split(whereSeparator: \.isWhitespace).map(String.init)

        // A redirect, a pipe or a comment ends the command and leaves it
        // whole; prose running on past it — a placeholder, or a word carrying
        // punctuation no argument would — means the line documents a shape
        // rather than something to run.
        let arguments = tokens.prefix { !shellBoundaries.contains($0) }
        let readable = arguments.prefix {
            !$0.hasPrefix("<") && !$0.contains(where: { ",.;:—".contains($0) })
        }

        let flags = readable.filter { $0.hasPrefix("--") && !hiddenFlags.contains($0) }
        // Subcommands come before the first flag; a value after a flag is not
        // one, and neither is a project name.
        let path = readable.prefix { !$0.hasPrefix("--") }.filter { $0.allSatisfy(\.isLowercase) }

        guard !path.isEmpty || !flags.isEmpty else { return nil }
        return SkillCommand(
            path: Array(path),
            flags: flags,
            arguments: Array(arguments),
            isComplete: readable.count == arguments.count,
            description: "\(name): " + (["xscaffold"] + readable).joined(separator: " ")
        )
    }
}

/// A directory the documented commands can run in: the `scaffold.yml` they
/// assume is in the working directory, and the `examples/` some of them name by
/// path.
private func withDocumentationWorkspace(_ body: (URL) throws -> Void) throws {
    try withTemporaryDirectory { root in
        try run(["config", "example", "--preset", "standard"]).standardOutput
            .write(to: root.appendingPathComponent("scaffold.yml"), atomically: true, encoding: .utf8)
        try FileManager.default.copyItem(
            at: repositoryRoot.appendingPathComponent("examples"),
            to: root.appendingPathComponent("examples")
        )
        try body(root)
    }
}

/// Documentation is executed rather than read here — the Skill by an agent, the
/// rest by whoever copies a line out of it — so a flag that was renamed and a
/// command that was removed are not typos. They are somebody running something
/// that exits 2 and then guessing.
///
/// `init`'s removal in v0.6 is what this exists for: the Skill named it for two
/// versions after it stopped working.
@Suite("The command lines the documentation gives out")
struct SkillCommandTests {
    @Test("there are command lines to check")
    func commandsExist() {
        #expect(skillCommands.count >= 20, "\(documentation.map(\.lastPathComponent))")
    }

    /// `--help` is the cheapest proof that a subcommand path exists: it parses
    /// the path, prints, and exits 0. A path that does not exist exits 2.
    @Test("every subcommand it names exists", arguments: skillCommands)
    func subcommandExists(command: SkillCommand) throws {
        let result = try run(command.path + ["--help"])

        #expect(result.exitStatus == 0, "\(command): \(result.standardError)")
    }

    /// The help for a command lists every flag it accepts, so a flag the Skill
    /// names and the help does not is a flag that no longer exists.
    @Test("every flag it names is accepted by that command", arguments: skillCommands)
    func flagsExist(command: SkillCommand) throws {
        let help = try run(command.path + ["--help"]).standardOutput

        for flag in command.flags {
            #expect(help.contains(flag), "\(command): \(flag)")
        }
    }

    /// The strongest form of the claim, for the commands that can make it:
    /// not "this flag appears in a help page" but "this exact line, as
    /// written, is one the binary accepts". Exit `2` is the CLI saying it does
    /// not understand what it was given, and exit `1` is it not knowing what
    /// happened; anything else means the line parsed and the command ran.
    ///
    /// Only the read-only commands, and only lines that were documented whole
    /// — a line ending in `<path>` documents a shape, and running it would
    /// prove nothing but that a placeholder is not a file.
    @Test(
        "every complete read-only line is one the binary accepts",
        arguments: skillCommands.filter { $0.isReadOnly && $0.isComplete }
    )
    func readOnlyCommandsRun(command: SkillCommand) throws {
        try withDocumentationWorkspace { workspace in
            let result = try run(command.arguments, in: workspace)

            #expect(result.exitStatus != ScaffoldExitCode.invalidArguments.rawValue,
                    "\(command): \(result.standardError)")
            #expect(result.exitStatus != ScaffoldExitCode.unexpectedFailure.rawValue,
                    "\(command): \(result.standardError)")
        }
    }

    /// The command the Skill tells an agent to reach for first, quoted in it as
    /// a document an agent parses.
    @Test("capabilities answers with the lists the Skill promises")
    func capabilitiesCarriesWhatTheSkillNames() throws {
        let output = try decoded(run(["capabilities", "--output", "json"]))
        let capabilities = try #require(output.capabilities)

        #expect(capabilities.variants.sorted() == Variant.all.map(\.name).sorted())
        #expect(capabilities.presets.sorted() == Preset.allowedValues.sorted())
        #expect(!capabilities.architectures.isEmpty)
        #expect(!capabilities.dependencyManagementModes.isEmpty)
    }

    /// The Skill prints an exit-code table and tells an agent to branch on it.
    /// A number that moved would send every agent down the wrong branch.
    @Test("the exit codes it lists are the ones the binary uses")
    func exitCodeTableIsCurrent() throws {
        let text = try String(contentsOf: skillPath, encoding: .utf8)

        for code in ScaffoldExitCode.allCases {
            #expect(text.contains("\(code.rawValue)"), "\(code)")
        }
    }
}
