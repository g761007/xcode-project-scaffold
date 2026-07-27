import Foundation
import ScaffoldCore
import ScaffoldSchema
import Testing

/// Every command this binary answers to. A subcommand added without a line
/// here fails `everyCommandIsFrozen`, which is how the list stays complete.
private let commandPaths: [[String]] = [
    [],
    ["new"],
    ["generate"],
    ["validate"],
    ["plan"],
    ["doctor"],
    ["capabilities"],
    ["config"],
    ["config", "example"]
]

/// The CLI surface, as the binary reports it.
///
/// Deliberately **not** the help text. Help prose is not contract — the
/// deprecation policy says so, and freezing it would make the help
/// unimprovable. What is contract is the shape: which commands exist, which
/// flags each takes, which are positional, which have short forms, and what an
/// omitted flag defaults to. All of that is in the `USAGE` line and the option
/// declarations; none of it is in the prose beside them.
///
/// `new` is the one command whose `USAGE` says `[<options>]` rather than
/// listing them: ArgumentParser collapses the line once a command carries
/// enough flags, which `new` began doing at twelve. Nothing is lost, because
/// the flags are read from the option declarations below it and appear on the
/// `options:` line either way — but a reader comparing the two shapes should
/// know the difference is the parser's, not this project's.
private let frozenSurface = """
xscaffold
  USAGE: xscaffold <subcommand>
  options: --help --version -h
  defaults:
xscaffold new
  USAGE: xscaffold new [<options>] [<name>]
  options: --advanced --dependency-manager --destination --force --help --open --output --preset \
--skip-generate --skip-git --validate-build --variant --version --yes -h -y
  defaults: text
xscaffold generate
  USAGE: xscaffold generate [--config <config>] [--destination <destination>] [--skip-git] [--skip-generate] \
[--output <output>] [--yes] [--force] [--validate-build]
  options: --config --destination --force --help --output --skip-generate --skip-git --validate-build \
--version --yes -h -y
  defaults: scaffold.yml text
xscaffold validate
  USAGE: xscaffold validate <path> [--output <output>]
  options: --help --output --version -h
  defaults: text
xscaffold plan
  USAGE: xscaffold plan [--config <config>] [--destination <destination>] [--skip-git] [--skip-generate] \
[--output <output>] [--files] [--resolved-config]
  options: --config --destination --files --help --output --resolved-config --skip-generate --skip-git \
--version -h
  defaults: scaffold.yml text
xscaffold doctor
  USAGE: xscaffold doctor [--output <output>] [--config <config>]
  options: --config --help --output --version -h
  defaults: text
xscaffold capabilities
  USAGE: xscaffold capabilities [--output <output>]
  options: --help --output --version -h
  defaults: text
xscaffold config
  USAGE: xscaffold config <subcommand>
  options: --help --version -h
  defaults:
xscaffold config example
  USAGE: xscaffold config example [--preset <preset>] [--variant <variant>] \
[--dependency-manager <dependency-manager>] [--output <output>]
  options: --dependency-manager --help --output --preset --variant --version -h
  defaults: text
"""

/// Reads the surface back off the binary, in the same shape the golden is
/// written in.
private func surface(of path: [String]) throws -> String {
    let help = try run(path + ["--help"]).standardOutput
    let lines = help.split(separator: "\n", omittingEmptySubsequences: false)

    let usage = lines.first { $0.hasPrefix("USAGE:") }.map(String.init) ?? "<no usage line>"

    // Only the declaration — everything up to the first double space. The
    // description beside a flag routinely names other flags, and picking those
    // up would make the surface depend on the prose it deliberately excludes.
    var names: Set<String> = []
    for line in lines where line.hasPrefix("  -") {
        let declaration = line.trimmingCharacters(in: .whitespaces)
            .components(separatedBy: "  ")[0]
            .replacing(/<[^>]*>/, with: "")
        names.formUnion(declaration.matches(of: /-{1,2}[A-Za-z][A-Za-z-]*/).map { String($0.output) })
    }

    let defaults = Set(help.matches(of: /default: ([^;)]+)/).map { String($0.output.1) })

    // Trailing whitespace trimmed per line: a command with no defaults would
    // otherwise end its line with a space, which no editor and no linter would
    // let the golden keep.
    return [
        (["xscaffold"] + path).joined(separator: " "),
        "  \(usage)",
        "  options: \(names.sorted().joined(separator: " "))",
        "  defaults: \(defaults.sorted().joined(separator: " "))"
    ]
    .map { line in
        String(line.reversed().drop { $0 == " " }.reversed())
    }
    .joined(separator: "\n")
}

/// The CLI freeze (#133). Scripts and the Skill are written against this
/// surface, so a renamed flag or a command that quietly stopped taking an
/// argument breaks automation that nobody can find, let alone fix.
///
/// What this pins and what it deliberately does not is recorded in
/// `docs/contracts.md`.
@Suite("The CLI is frozen")
struct CLIFreezeTests {
    @Test("the surface is the one it was frozen at")
    func surfaceIsFrozen() throws {
        let read = try commandPaths.map(surface(of:)).joined(separator: "\n")

        #expect(read == frozenSurface)
    }

    /// The golden above lists commands; this proves the list is all of them.
    /// A new subcommand shows up in its parent's help and in nothing else.
    @Test("every command the binary answers to is in the golden")
    func everyCommandIsFrozen() throws {
        var expected: Set<[String]> = []
        for path in commandPaths {
            let help = try run(path + ["--help"]).standardOutput
            guard let block = help.range(of: "SUBCOMMANDS:") else { continue }

            for line in help[block.upperBound...].split(separator: "\n") {
                guard line.hasPrefix("  "), !line.hasPrefix("   ") else { continue }
                let name = line.trimmingCharacters(in: .whitespaces).components(separatedBy: " ")[0]
                guard !name.isEmpty, name != "See" else { continue }
                expected.insert(path + [name])
            }
        }

        // `init` is a tombstone: hidden from help, kept so that typing it gets
        // a pointer rather than an unknown-command shrug.
        #expect(expected.subtracting(Set(commandPaths)).isEmpty)
    }

    /// §11.4's numbers, all of them. `ExitCodeTests` pins which failure exits
    /// with which code; this pins that the set itself has not moved.
    @Test("the exit codes are the ones they were frozen at")
    func exitCodesAreFrozen() {
        let frozen: [ScaffoldExitCode: Int32] = [
            .success: 0, .unexpectedFailure: 1, .invalidArguments: 2,
            .configurationParsingFailure: 3, .validationFailure: 4,
            .templateResolutionFailure: 5, .fileConflict: 6, .generationFailure: 7,
            .externalCommandFailure: 8, .buildValidationFailure: 9,
            .environmentRequirementMissing: 10, .userCancelled: 130
        ]

        #expect(ScaffoldExitCode.allCases.count == frozen.count)
        for (code, number) in frozen {
            #expect(code.rawValue == number, "\(code)")
        }
    }

    /// The rule the whole machine-readable contract rests on (§11.3). A
    /// diagnostic that reached stdout would make every caller's parse fail on
    /// the run where it mattered most.
    @Test("under --output json, stdout is one document and nothing else", arguments: [
        ["capabilities"],
        ["config", "example"]
    ])
    func stdoutCarriesOnlyTheDocument(path: [String]) throws {
        let result = try run(path + ["--output", "json"])

        #expect(result.exitStatus == 0)
        #expect(throws: Never.self) {
            try JSONSerialization.jsonObject(with: Data(result.standardOutput.utf8))
        }
    }
}
