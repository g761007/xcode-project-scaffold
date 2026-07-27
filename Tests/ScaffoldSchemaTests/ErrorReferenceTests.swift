import Foundation
import ScaffoldSchema
import Testing

/// Keeps the CLI reference honest about the three strings a failure carries.
///
/// `ScaffoldErrorCode` and `ScaffoldPhase` are frozen: the deprecation policy
/// prices a change to either at a major version. What held them before this was
/// `allCases.count` and a regex — enough to notice a code arriving, not enough
/// to notice one being renamed. `JSONFreezeTests.phasesEncodeAsNames` looks like
/// it pins the phase strings and does not: it compares `rawValue` against
/// `rawValue`, which proves the encoding and nothing about the spelling.
///
/// So the strings are pinned the way `ValidationCode` already is — against a
/// document a caller actually reads. Renaming one now fails here, and the fix
/// is to rename it in the table too, which is the sentence someone reviewing a
/// breaking change needs to see.
///
/// The table carries the exit code and the phase beside each code because those
/// are what a caller branches on together, and pinning all three costs one
/// parse rather than three.
@Suite("The CLI reference's error table")
struct ErrorReferenceTests {
    /// Found relative to this file: this is a document in the repository, not a
    /// resource of the package.
    static let reference = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // ScaffoldSchemaTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // repository root
        .appendingPathComponent("docs/cli-reference.md")

    /// The header the table is found by. Changing it here and in the document
    /// is allowed; changing it in only one place is what this test is for.
    static let header = "| `error.code` | `exitCode` | `phase` |"

    /// What the table writes where a code names no phase.
    static let noPhase = "—"

    struct Row {
        var code: String
        var exitCode: String
        var phase: String
    }

    /// The rows between the header's separator and the first line that is not a
    /// table row. Deliberately not a Markdown parser: the shape asserted here is
    /// the shape the document has to keep, and a row that stops looking like one
    /// should fall out of the table rather than be recovered.
    private func rows() throws -> [Row] {
        let text = try String(contentsOf: Self.reference, encoding: .utf8)
        let lines = text.components(separatedBy: .newlines)

        guard let start = lines.firstIndex(of: Self.header) else {
            Issue.record("docs/cli-reference.md has no table headed \(Self.header)")
            return []
        }

        return lines[lines.index(start, offsetBy: 2)...]
            .prefix { $0.hasPrefix("|") }
            .compactMap { line in
                let cells = line
                    .split(separator: "|", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }

                guard cells.count == 3 else { return nil }
                return Row(
                    code: cells[0].trimmingCharacters(in: CharacterSet(charactersIn: "`")),
                    exitCode: cells[1].trimmingCharacters(in: CharacterSet(charactersIn: "`")),
                    phase: cells[2].trimmingCharacters(in: CharacterSet(charactersIn: "`"))
                )
            }
    }

    @Test("every error code is documented")
    func documentsEveryCode() throws {
        let documented = try Set(rows().map(\.code))
        let missing = ScaffoldErrorCode.allCases.map(\.rawValue).filter { !documented.contains($0) }

        #expect(missing.isEmpty)
    }

    /// The other direction, which the first assertion cannot see: a code that
    /// was renamed or removed, still listed as though a caller could receive it.
    @Test("no code it documents has since been renamed or removed")
    func documentsNoStaleCode() throws {
        let known = Set(ScaffoldErrorCode.allCases.map(\.rawValue))
        let documented = try Set(rows().map(\.code))

        #expect(documented.subtracting(known).isEmpty)
    }

    /// Both directions for the phases, for free: every phase is one some code
    /// reports — `ErrorCodeContractTests.everyPhaseIsReachable` holds that — so
    /// the table's third column has to name all ten and nothing else.
    @Test("the phase column names every phase and only real ones")
    func documentsEveryPhase() throws {
        let documented = try Set(rows().map(\.phase)).subtracting([Self.noPhase])
        let known = Set(ScaffoldPhase.allCases.map(\.rawValue))

        #expect(known.subtracting(documented).isEmpty, "undocumented")
        #expect(documented.subtracting(known).isEmpty, "no longer a phase")
    }

    /// The rows have to say what the types say, or the table is a second
    /// contract that disagrees with the first.
    @Test("each row states the code's own exit code and phase")
    func rowsMatchTheTypes() throws {
        let byName = Dictionary(
            uniqueKeysWithValues: ScaffoldErrorCode.allCases.map { ($0.rawValue, $0) }
        )

        for row in try rows() {
            guard let code = byName[row.code] else { continue }

            #expect(row.exitCode == String(code.exitCode.rawValue), "\(row.code)")
            #expect(row.phase == (code.phase?.rawValue ?? Self.noPhase), "\(row.code)")
        }
    }
}
