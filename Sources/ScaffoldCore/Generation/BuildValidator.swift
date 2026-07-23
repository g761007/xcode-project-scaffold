import Foundation
import ScaffoldSchema

/// Builds a generated project, for `--validate-build`.
///
/// Off by default (§10.1): the real audience for build validation is this
/// project's own CI, not everyone creating a project, and it costs a minute of
/// compilation. Whoever asks for it gets a plain answer — the project you just
/// made compiles, or here is what the compiler said.
///
/// A failure here does **not** remove the project. The generation succeeded;
/// what failed is a check on top of it, and deleting the evidence would be a
/// strange way to report a build error.
public struct BuildValidator: Sendable {
    private let processRunner: any ProcessRunner

    public init(processRunner: any ProcessRunner = SystemProcessRunner()) {
        self.processRunner = processRunner
    }

    public func validate(_ configuration: ProjectConfiguration, at destination: URL) throws {
        let command = buildCommand(for: configuration)
        let result = try processRunner.run(ProcessInvocation(
            executable: command.executable,
            arguments: command.arguments,
            workingDirectory: destination
        ))

        guard result.succeeded else {
            throw BuildValidationError(
                command: command,
                exitStatus: result.exitStatus,
                output: result.combinedOutput
            )
        }
    }

    private func buildCommand(for configuration: ProjectConfiguration) -> PlannedCommand {
        PlannedCommand(
            executable: "xcodebuild",
            arguments: [
                "build",
                "-project", configuration.projectFileName,
                "-scheme", XcodeGenSpecBuilder().makeSpec(for: configuration).defaultSchemeName,
                "-destination", destination(for: configuration.product.platform),
                "-quiet"
            ],
            purpose: "Check that the generated project compiles"
        )
    }

    /// Generic rather than a named simulator. §12.2 recorded why naming a device
    /// fails on someone else's machine: the device has to exist in an installed
    /// runtime, and xscaffold cannot know which ones are installed. A generic
    /// destination needs none of them.
    private func destination(for platform: ApplePlatform) -> String {
        switch platform {
        case .iOS: "generic/platform=iOS Simulator"
        case .macOS: "platform=macOS"
        }
    }
}

public struct BuildValidationError: Error, Equatable, Sendable {
    public let command: PlannedCommand
    public let exitStatus: Int32
    public let output: String

    public var exitCode: ScaffoldExitCode {
        .buildValidationFailure
    }
}

extension BuildValidationError: CustomStringConvertible {
    public var description: String {
        "The generated project did not build: `\(command.displayString)` "
            + "failed with exit status \(exitStatus)."
            + (output.isEmpty ? "" : "\n\(output.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
}
