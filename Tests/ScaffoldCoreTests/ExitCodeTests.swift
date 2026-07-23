import Foundation
@testable import ScaffoldCore
import ScaffoldSchema
import Testing

private let destination = URL(fileURLWithPath: "/tmp/MyApp")

/// §11.4's table is what a script or the Skill branches on, so which failure
/// exits with which code is a contract and not an implementation detail. Pinned
/// here rather than exercised through the binary, so that a wrong answer is a
/// test failure rather than a surprise in someone's pipeline.
@Suite("Which failure exits with which code")
struct ExitCodeTests {
    @Test("a destination that cannot be used is a file conflict", arguments: [
        GenerationError.destinationNotEmpty(destination),
        GenerationError.destinationIsNotADirectory(destination),
        GenerationError.cannotReplaceDirectory(destination)
    ])
    func conflicts(error: GenerationError) {
        #expect(error.exitCode == .fileConflict)
    }

    @Test("a missing tool is a missing requirement, not a failed command")
    func missingTool() {
        #expect(GenerationError.executableNotFound("xcodegen").exitCode == .environmentRequirementMissing)
    }

    @Test("a command that ran and failed is an external command failure")
    func commandFailure() {
        let error = GenerationError.commandFailed(
            PlannedCommand(executable: "git", arguments: ["init"], purpose: "Start a repository"),
            exitStatus: 128,
            output: ""
        )

        #expect(error.exitCode == .externalCommandFailure)
    }

    @Test("a plan that would escape the destination is a generation failure")
    func unsafePath() {
        #expect(GenerationError.unsafePlannedPath("../escaped").exitCode == .generationFailure)
    }

    /// Whether the destination could be cleaned up afterwards says nothing
    /// about why the run failed, and a caller branching on the code should not
    /// have to care.
    @Test("wrapping a failure does not change what it exits with")
    func wrapped() {
        let underlying = GenerationError.commandFailed(
            PlannedCommand(executable: "git", arguments: ["init"], purpose: "Start a repository"),
            exitStatus: 128,
            output: ""
        )
        let wrapped = GenerationError.failedLeavingFiles(underlying, in: destination)

        #expect(wrapped.exitCode == underlying.exitCode)
    }

    @Test("a project that does not compile is its own kind of failure")
    func buildFailure() {
        let error = BuildValidationError(
            command: PlannedCommand(executable: "xcodebuild", arguments: [], purpose: "Build"),
            exitStatus: 65,
            output: ""
        )

        #expect(error.exitCode == .buildValidationFailure)
    }

    /// The numbers themselves are the contract — a caller matches on `4`, not
    /// on `.validationFailure`.
    @Test("the numbers are the ones in §11.4")
    func numbers() {
        #expect(ScaffoldExitCode.success.rawValue == 0)
        #expect(ScaffoldExitCode.unexpectedFailure.rawValue == 1)
        #expect(ScaffoldExitCode.invalidArguments.rawValue == 2)
        #expect(ScaffoldExitCode.configurationParsingFailure.rawValue == 3)
        #expect(ScaffoldExitCode.validationFailure.rawValue == 4)
        #expect(ScaffoldExitCode.templateResolutionFailure.rawValue == 5)
        #expect(ScaffoldExitCode.fileConflict.rawValue == 6)
        #expect(ScaffoldExitCode.generationFailure.rawValue == 7)
        #expect(ScaffoldExitCode.externalCommandFailure.rawValue == 8)
        #expect(ScaffoldExitCode.buildValidationFailure.rawValue == 9)
        #expect(ScaffoldExitCode.environmentRequirementMissing.rawValue == 10)
    }
}
