import Foundation
@testable import ScaffoldSchema
import Testing

/// §23 asks every error for a code, a phase, an exit code and something to do
/// about it. The point of walking `allCases` rather than spot-checking is
/// completeness: adding a code without deciding what it exits with, or without
/// writing a suggestion, has to be a test failure rather than a discovery made
/// by whoever hits it first.
@Suite("Error code contract")
struct ErrorCodeContractTests {
    @Test("every code is the SCREAMING_SNAKE name a caller greps for")
    func codesAreWellFormed() {
        for code in ScaffoldErrorCode.allCases {
            #expect(code.rawValue.wholeMatch(of: /[A-Z][A-Z_]*[A-Z]/) != nil, "\(code.rawValue)")
        }
    }

    /// Not "please check your configuration". A suggestion exists so that the
    /// reader's next move is on screen: a command to run, a flag to pass, a
    /// field to edit.
    @Test("every code says what to do about it")
    func everyCodeHasARecoverySuggestion() {
        for code in ScaffoldErrorCode.allCases {
            let suggestion = code.recoverySuggestion
            #expect(!suggestion.isEmpty, "\(code.rawValue)")
            #expect(suggestion.hasSuffix("."), "\(code.rawValue)")
            #expect(suggestion.count > 20, "\(code.rawValue): \(suggestion)")
        }
    }

    /// Every failure knows where it happened, except the one that by
    /// definition does not: `UNEXPECTED_FAILURE` is what is left when nothing
    /// fits, and a phase for it would be a guess printed as a fact.
    @Test("every code but the catch-all names a phase")
    func everyCodeHasAPhase() {
        for code in ScaffoldErrorCode.allCases where code != .unexpectedFailure {
            #expect(code.phase != nil, "\(code.rawValue)")
        }

        #expect(ScaffoldErrorCode.unexpectedFailure.phase == nil)
    }

    /// The pairing is the contract: a caller that reads `POD_INSTALL_FAILED`
    /// and a caller that reads `8` have to be looking at the same failure.
    @Test("each code exits with the number §11.4 gives it", arguments: [
        (ScaffoldErrorCode.invalidArguments, ScaffoldExitCode.invalidArguments),
        (.configurationUnreadable, .configurationParsingFailure),
        (.configurationMalformed, .configurationParsingFailure),
        (.schemaVersionUnsupported, .configurationParsingFailure),
        (.configurationInvalid, .validationFailure),
        (.templateConflict, .templateResolutionFailure),
        (.templateResolutionFailed, .templateResolutionFailure),
        (.outputDirectoryNotEmpty, .fileConflict),
        (.outputDirectoryHasProject, .fileConflict),
        (.outputPathNotADirectory, .fileConflict),
        (.outputPathBlockedByDirectory, .fileConflict),
        (.unsafePlannedPath, .generationFailure),
        (.xcodegenNotInstalled, .environmentRequirementMissing),
        (.cocoapodsNotInstalled, .environmentRequirementMissing),
        (.bundlerNotInstalled, .environmentRequirementMissing),
        (.executableNotFound, .environmentRequirementMissing),
        (.environmentRequirementMissing, .environmentRequirementMissing),
        (.xcodegenFailed, .externalCommandFailure),
        (.podInstallFailed, .externalCommandFailure),
        (.commandFailed, .externalCommandFailure),
        (.workspaceNotGenerated, .generationFailure),
        (.generationFailed, .generationFailure),
        (.buildValidationFailed, .buildValidationFailure),
        (.generationCancelled, .userCancelled),
        (.unexpectedFailure, .unexpectedFailure)
    ])
    func exitCodes(code: ScaffoldErrorCode, expected: ScaffoldExitCode) {
        #expect(code.exitCode == expected)
    }

    /// The table above has to keep covering the enum, or a new code could be
    /// added and go unpinned while every other test still passes.
    @Test("the table above covers every code")
    func exitCodeTableIsComplete() {
        #expect(ScaffoldErrorCode.allCases.count == 25)
    }

    /// Which stage was under way decides whether anything reached the disk,
    /// which is the first thing a reader wants to know.
    @Test("the phase says which stage was under way", arguments: [
        (ScaffoldErrorCode.invalidArguments, ScaffoldPhase.invocation),
        (.configurationMalformed, .configuration),
        (.configurationInvalid, .validation),
        (.templateConflict, .planning),
        (.generationCancelled, .confirmation),
        (.outputDirectoryNotEmpty, .generation),
        (.xcodegenFailed, .projectGeneration),
        (.podInstallFailed, .dependencyInstallation),
        (.buildValidationFailed, .buildValidation),
        (.environmentRequirementMissing, .environmentCheck)
    ])
    func phases(code: ScaffoldErrorCode, expected: ScaffoldPhase) {
        #expect(code.phase == expected)
    }
}

@Suite("Error wire format")
struct ScaffoldErrorWireFormatTests {
    /// Derived, not passed: the alternative is a document naming a file
    /// conflict while exiting 0, which no caller could defend itself against.
    @Test("the exit code and the suggestion come from the code")
    func derivedFromCode() {
        let error = ScaffoldError(code: .outputDirectoryNotEmpty, message: "'/tmp/App' is not empty.")

        #expect(error.exitCode == .fileConflict)
        #expect(error.recoverySuggestion == ScaffoldErrorCode.outputDirectoryNotEmpty.recoverySuggestion)
    }

    @Test("the code encodes as the name, not the Swift case")
    func encodesRawCode() throws {
        let error = ScaffoldError(
            code: .podInstallFailed,
            message: "`pod install` failed with exit status 1.",
            command: "pod install",
            path: "/tmp/App"
        )

        let decoded = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(error)
        ) as? [String: Any]

        #expect(decoded?["code"] as? String == "POD_INSTALL_FAILED")
        #expect(decoded?["exitCode"] as? Int == 8)
        #expect(decoded?["command"] as? String == "pod install")
        #expect(decoded?["path"] as? String == "/tmp/App")
    }

    /// Absent, not null: a caller asking "was a command involved?" must not be
    /// told yes by a failure that never ran one.
    @Test("a failure with no command and no path carries neither key")
    func absentKeys() throws {
        let data = try JSONEncoder().encode(
            ScaffoldError(code: .configurationInvalid, message: "It cannot be generated.")
        )
        let encoded = try #require(String(bytes: data, encoding: .utf8))

        #expect(!encoded.contains("command"))
        #expect(!encoded.contains("path"))
    }

    @Test("a failure document carries the phase and the error together")
    func failureOutput() {
        let output = CommandOutput(
            command: "generate",
            error: ScaffoldError(code: .xcodegenFailed, message: "`xcodegen generate` failed.")
        )

        #expect(output.ok == false)
        #expect(output.exitCode == .externalCommandFailure)
        #expect(output.phase == .projectGeneration)
        #expect(output.message == "`xcodegen generate` failed.")
        #expect(output.error?.code == .xcodegenFailed)
    }

    /// The one code that can arrive from more than one stage says so, rather
    /// than reporting the default and being wrong half the time.
    @Test("a passed phase wins over the code's own")
    func overriddenPhase() {
        let output = CommandOutput(
            command: "new",
            error: ScaffoldError(code: .executableNotFound, message: "'xcodebuild' is not installed."),
            phase: .buildValidation
        )

        #expect(output.phase == .buildValidation)
    }
}
