import ArgumentParser
import ScaffoldCore
import ScaffoldSchema

/// The tombstone `init` leaves behind (ADR-0007): the deprecation period ended
/// in v0.6, and someone typing it deserves the two commands that replaced it,
/// not an unknown-command shrug. Hidden, so the help never advertises what
/// exists only to redirect.
///
/// The refusal is a `ValidationError` on purpose: that path flows through the
/// root's reporting, which keeps §11.3's promise — stdout under
/// `--output json` is a JSON document, even for a command that no longer
/// exists to know json was asked for.
struct RemovedInitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Removed in v0.6. Use generate, or new --variant.",
        shouldDisplay: false
    )

    @Argument(parsing: .allUnrecognized)
    var everythingElse: [String] = []

    func validate() throws {
        throw ValidationError("init was removed in v0.6. Use 'xscaffold generate --config <file>' "
            + "for a configuration, or 'xscaffold new <name> --variant <variant> --yes' for a "
            + "one-line project.")
    }

    func run() throws {}
}
