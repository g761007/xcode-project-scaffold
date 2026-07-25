import Foundation
import ScaffoldCore
import ScaffoldSchema
import Testing

private let malformedConfiguration = """
project:
  name: Bookshelf
  bundleIdentifier: com.example.bookshelf
interface:
  primary: nonsense
"""

/// §23 from the outside. Everything below can only be checked once a process
/// has run and exited: that stdout under `--output json` is a parseable
/// document *on failure*, that it names a code and a phase, and that the text
/// form says the same things to a person.
@Suite("The error contract, from the outside")
struct CommandLineErrorContractTests {
    @Test("a destination conflict names the code, the phase and the directory")
    func destinationConflict() throws {
        try withTemporaryDirectory { root in
            let path = root.appendingPathComponent("scaffold.yml")
            try validConfiguration.write(to: path, atomically: true, encoding: .utf8)
            let destination = root.appendingPathComponent("Bookshelf")
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try "mine".write(to: destination.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

            let result = try xscaffold(
                "generate", "--config", path.path, "--destination", destination.path,
                "--yes", "--skip-git", "--skip-generate", "--output", "json"
            )
            let output = try decoded(result)

            #expect(result.exitStatus == ScaffoldExitCode.fileConflict.rawValue)
            #expect(output.ok == false)
            #expect(output.phase == .generation)
            #expect(output.error?.code == .outputDirectoryNotEmpty)
            #expect(output.error?.exitCode == .fileConflict)
            #expect(output.error?.path == destination.path)
            #expect(output.error?.recoverySuggestion.contains("--force") == true)
        }
    }

    @Test("a configuration that cannot be generated is a validation failure")
    func validationFailure() throws {
        try withTemporaryDirectory { root in
            let path = root.appendingPathComponent("scaffold.yml")
            try invalidConfiguration.write(to: path, atomically: true, encoding: .utf8)

            let output = try decoded(xscaffold("validate", path.path, "--output", "json"))

            #expect(output.phase == .validation)
            #expect(output.error?.code == .configurationInvalid)
            #expect(output.issues?.isEmpty == false)
        }
    }

    /// A file that is not there and a file that is not valid are two different
    /// problems with two different fixes, and both exit 3 — which is exactly
    /// why the code has to tell them apart.
    @Test("an unreadable configuration and a malformed one are different codes")
    func configurationFailures() throws {
        try withTemporaryDirectory { root in
            let missing = try decoded(xscaffold(
                "validate", root.appendingPathComponent("absent.yml").path, "--output", "json"
            ))

            #expect(missing.phase == .configuration)
            #expect(missing.error?.code == .configurationUnreadable)
            #expect(missing.exitCode == .configurationParsingFailure)

            let path = root.appendingPathComponent("scaffold.yml")
            try malformedConfiguration.write(to: path, atomically: true, encoding: .utf8)

            let malformed = try decoded(xscaffold("validate", path.path, "--output", "json"))

            #expect(malformed.phase == .configuration)
            #expect(malformed.error?.code == .configurationMalformed)
            #expect(malformed.error?.path == path.path)
        }
    }

    /// A document from a later version is refused before anything reads it,
    /// with its own code — not as a malformed document, because nothing about
    /// its shape is wrong, and not as a validation issue, because field-level
    /// advice about a dialect this binary cannot read is advice about the
    /// wrong problem.
    @Test("a schema version this binary does not understand is refused")
    func unsupportedSchemaVersion() throws {
        try withTemporaryDirectory { root in
            let path = root.appendingPathComponent("scaffold.yml")
            try "schemaVersion: 2\n\(validConfiguration)"
                .write(to: path, atomically: true, encoding: .utf8)

            let result = try xscaffold("validate", path.path, "--output", "json")
            let output = try decoded(result)

            #expect(result.exitStatus == ScaffoldExitCode.configurationParsingFailure.rawValue)
            #expect(output.phase == .configuration)
            #expect(output.error?.code == .schemaVersionUnsupported)
            #expect(output.issues == nil, "a document it cannot read produces no field-level advice")
            #expect(output.error?.message.contains("schemaVersion 2") == true)
        }
    }

    /// The version it refuses and the version `capabilities` advertises have to
    /// be the same set, or an agent that consults one and obeys the other is
    /// wrong in a way it cannot detect.
    @Test("what capabilities advertises is what a document may state")
    func capabilitiesMatchesWhatIsAccepted() throws {
        try withTemporaryDirectory { root in
            let advertised = try #require(
                try decoded(run(["capabilities", "--output", "json"])).capabilities
            ).schemaVersions

            for version in advertised {
                let path = root.appendingPathComponent("scaffold.yml")
                try "schemaVersion: \(version)\n\(validConfiguration)"
                    .write(to: path, atomically: true, encoding: .utf8)

                #expect(try run(["validate", path.path]).exitStatus == 0, "schemaVersion \(version)")
            }
        }
    }

    /// §11.3's promise has to hold before any command exists to keep it: the
    /// arguments were wrong, so nothing parsed, and stdout is still JSON.
    @Test("arguments that do not parse are still reported as a document")
    func invalidArguments() throws {
        let result = try xscaffold("generate", "--nonsense", "--output", "json")
        let output = try decoded(result)

        #expect(result.exitStatus == ScaffoldExitCode.invalidArguments.rawValue)
        #expect(output.phase == .invocation)
        #expect(output.error?.code == .invalidArguments)
        #expect(output.command == "generate")
    }

    /// The same three facts a caller parses out of JSON, in the form a person
    /// reads: the code to look up, the sentence, and the one thing to do.
    @Test("the text form leads with the code and ends with the suggestion")
    func textForm() throws {
        try withTemporaryDirectory { root in
            let path = root.appendingPathComponent("scaffold.yml")
            try invalidConfiguration.write(to: path, atomically: true, encoding: .utf8)

            let result = try xscaffold("validate", path.path)

            #expect(result.standardError.contains("Error: CONFIGURATION_INVALID:"))
            #expect(result.standardError.contains(
                "Try: \(ScaffoldErrorCode.configurationInvalid.recoverySuggestion)"
            ))
        }
    }
}
