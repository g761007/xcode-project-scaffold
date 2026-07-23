import Foundation
import ScaffoldSchema

/// Serialises a `CommandOutput` for `--output json`.
///
/// The formatting is part of the contract, not a preference:
///
/// - **One line, not pretty-printed.** This is written for programs; a person
///   who wants it laid out has `jq`.
/// - **Keys sorted.** The order is then guaranteed rather than incidental,
///   which is what lets the contract be pinned by comparing text.
/// - **Slashes unescaped.** Every path in the output would otherwise arrive as
///   `\/tmp\/MyApp` — legal JSON that no one can read in a log.
public struct CommandOutputEncoder: Sendable {
    public init() {}

    public func encode(_ output: CommandOutput) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

        // Against `optional_data_string_conversion`: JSON is UTF-8 by
        // definition and `JSONEncoder` emits it, so the failable initializer
        // would only add a branch that cannot be taken — and whose only honest
        // fallback would be to fail at producing the output that says why
        // something failed.
        // swiftlint:disable:next optional_data_string_conversion
        return try String(decoding: encoder.encode(output), as: UTF8.self)
    }
}
