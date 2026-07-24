import Foundation
import ScaffoldSchema

/// Everything that can go wrong once a plan starts being carried out.
///
/// Parsing, validation and planning have their own error types and all happen
/// before this point, so anything here means the destination — or the machine —
/// was not what the run needed.
public enum GenerationError: Error, Equatable, Sendable {
    /// The soft tier of §13.3: a non-empty directory with no project in it.
    /// `--force` moves in; nothing but a planned path's namesake is touched.
    case destinationNotEmpty(URL)
    /// The hard tier of §13.3: the directory already holds a project — an
    /// `.xcodeproj`, an `.xcworkspace`, a `project.yml` or source code — and no
    /// flag can write into it. xscaffold creates new projects; the moment it
    /// might be updating an existing one, it stops.
    case destinationHasProject(URL, marker: String)
    case destinationIsNotADirectory(URL)
    /// A directory sitting where the plan needs a file. Refused rather than
    /// removed: `--force` replaces files, and removing a directory would take
    /// everything under it with no way back (§10.2).
    case cannotReplaceDirectory(URL)
    /// A planned path that would write outside the destination.
    case unsafePlannedPath(String)
    case executableNotFound(String)
    case commandFailed(PlannedCommand, exitStatus: Int32, output: String)
    /// pod install returned success and the workspace it exists to produce is
    /// not there — possible with a degenerate Podfile, and better found now
    /// than by the first xcodebuild.
    case workspaceNotProduced(String)

    /// A failure that could not be undone, because the destination was not
    /// xscaffold's to remove (§10.2). Wraps the failure rather than replacing it
    /// so the reader still learns what went wrong, and gets told what is now in
    /// the directory they named.
    indirect case failedLeavingFiles(GenerationError, in: URL)
}

extension GenerationError {
    /// What the CLI exits with (§11.4).
    ///
    /// Here rather than in the CLI so that it can be tested without running a
    /// binary, and so that adding a case makes the compiler ask what it means
    /// to a caller — the one question a new failure mode must not skip.
    public var exitCode: ScaffoldExitCode {
        switch self {
        case .destinationNotEmpty, .destinationHasProject, .destinationIsNotADirectory, .cannotReplaceDirectory:
            .fileConflict
        case .executableNotFound:
            .environmentRequirementMissing
        case .commandFailed:
            .externalCommandFailure
        case .workspaceNotProduced:
            .generationFailure
        case .unsafePlannedPath:
            .generationFailure
        // What could not be undone does not change why it failed.
        case let .failedLeavingFiles(underlying, _):
            underlying.exitCode
        }
    }
}

extension GenerationError: CustomStringConvertible {
    public var description: String {
        switch self {
        // The two §13.3 tiers open with their contract names, the way a
        // ValidationIssue opens with its code: the part a script greps for and
        // a reader looks up.
        case let .destinationNotEmpty(destination):
            "OUTPUT_DIRECTORY_NOT_EMPTY: '\(destination.path)' already exists and is not empty. "
                + "Choose an empty destination, or pass --force to write into it anyway."

        case let .destinationHasProject(destination, marker):
            "OUTPUT_DIRECTORY_HAS_PROJECT: '\(destination.path)' contains an existing project "
                + "(\(marker)). xscaffold creates new projects and does not update existing "
                + "projects, so no flag makes this destination writable."

        case let .destinationIsNotADirectory(destination):
            "'\(destination.path)' already exists and is not a directory."

        case let .cannotReplaceDirectory(path):
            "'\(path.path)' is a directory, and the project needs a file there. "
                + "Move it out of the way and run this again."

        case let .unsafePlannedPath(path):
            "The plan contains '\(path)', which would write outside the destination."

        case let .executableNotFound(executable):
            "'\(executable)' is not installed, or not on the PATH."

        case let .commandFailed(command, exitStatus, output):
            "`\(command.displayString)` "
                + "failed with exit status \(exitStatus), while trying to: \(command.purpose)."
                + (output.isEmpty ? "" : "\n\(output.trimmingCharacters(in: .whitespacesAndNewlines))")

        case let .workspaceNotProduced(fileName):
            "pod install finished, but '\(fileName)' was not produced. "
                + "Run `pod install` in the project to see what CocoaPods decided."

        case let .failedLeavingFiles(underlying, destination):
            "\(underlying)\n"
                + "The generated files are still in '\(destination.path)': it already existed, "
                + "so xscaffold did not remove it."
        }
    }
}
