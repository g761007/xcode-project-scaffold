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

extension GenerationError: ReportableError {
    /// The contract name for each failure (§23).
    ///
    /// Here rather than in the CLI so that it can be tested without running a
    /// binary, and so that adding a case makes the compiler ask what it means
    /// to a caller — the one question a new failure mode must not skip.
    public var errorCode: ScaffoldErrorCode {
        switch self {
        case .destinationNotEmpty: .outputDirectoryNotEmpty
        case .destinationHasProject: .outputDirectoryHasProject
        case .destinationIsNotADirectory: .outputPathNotADirectory
        case .cannotReplaceDirectory: .outputPathBlockedByDirectory
        case .unsafePlannedPath: .unsafePlannedPath
        case .workspaceNotProduced: .workspaceNotGenerated
        case let .executableNotFound(executable): Tool(executable: executable).missingCode
        case let .commandFailed(command, _, _): Tool(command).failureCode
        // What could not be undone does not change why it failed: a caller
        // branching on the code is asking why, and the leftover directory is
        // in `relevantPath`.
        case let .failedLeavingFiles(underlying, _): underlying.errorCode
        }
    }

    /// Which tool was missing, or failed, decides the stage — the same code
    /// arrives from generation, from the generator run and from a build.
    /// Anything else takes the code's own phase.
    public var reportedPhase: ScaffoldPhase? {
        switch self {
        case let .executableNotFound(executable): Tool(executable: executable).phase
        case let .commandFailed(command, _, _): Tool(command).phase
        case let .failedLeavingFiles(underlying, _): underlying.reportedPhase
        default: errorCode.phase
        }
    }

    public var failedCommand: String? {
        switch self {
        case let .commandFailed(command, _, _): command.displayString
        case let .failedLeavingFiles(underlying, _): underlying.failedCommand
        default: nil
        }
    }

    public var relevantPath: String? {
        switch self {
        case let .destinationNotEmpty(url),
             let .destinationHasProject(url, _),
             let .destinationIsNotADirectory(url),
             let .cannotReplaceDirectory(url):
            url.path
        case let .unsafePlannedPath(path):
            path
        case let .workspaceNotProduced(fileName):
            fileName
        // The destination, not the underlying failure's path: what the reader
        // now has to deal with is the directory that still has files in it.
        case let .failedLeavingFiles(_, destination):
            destination.path
        default:
            nil
        }
    }

    /// What the CLI exits with (§11.4). One mapping, through the code, so that
    /// the number and the name cannot come to disagree.
    public var exitCode: ScaffoldExitCode {
        errorCode.exitCode
    }
}

/// The tool a planned command belongs to, taken from the executable's name —
/// which is the thing that identifies it. `bundle` is Bundler on its own and
/// CocoaPods when it is running `pod`, because that is what failed.
private enum Tool {
    case xcodegen
    case cocoapods
    case bundler
    case xcodebuild
    case other

    init(executable: String, arguments: [String] = []) {
        switch executable {
        case "xcodegen": self = .xcodegen
        case "pod": self = .cocoapods
        case "bundle": self = arguments.contains("pod") ? .cocoapods : .bundler
        case "xcodebuild": self = .xcodebuild
        default: self = .other
        }
    }

    init(_ command: PlannedCommand) {
        self.init(executable: command.executable, arguments: command.arguments)
    }

    var missingCode: ScaffoldErrorCode {
        switch self {
        case .xcodegen: .xcodegenNotInstalled
        case .cocoapods: .cocoapodsNotInstalled
        case .bundler: .bundlerNotInstalled
        case .xcodebuild, .other: .executableNotFound
        }
    }

    /// Bundler has no failure code of its own in §23: `bundle install` failing
    /// is a command that failed, and its output says which gem.
    var failureCode: ScaffoldErrorCode {
        switch self {
        case .xcodegen: .xcodegenFailed
        case .cocoapods: .podInstallFailed
        case .bundler, .xcodebuild, .other: .commandFailed
        }
    }

    var phase: ScaffoldPhase {
        switch self {
        case .xcodegen: .projectGeneration
        case .cocoapods, .bundler: .dependencyInstallation
        case .xcodebuild: .buildValidation
        case .other: .generation
        }
    }
}

extension GenerationError: CustomStringConvertible {
    /// What happened, and nothing else. The contract name and what to do about
    /// it are the code's (§23), and are printed alongside this by whoever
    /// reports it — repeating them here would have every failure say the same
    /// thing twice.
    public var description: String {
        switch self {
        case let .destinationNotEmpty(destination):
            "'\(destination.path)' already exists and is not empty."

        case let .destinationHasProject(destination, marker):
            "'\(destination.path)' contains an existing project (\(marker))."

        case let .destinationIsNotADirectory(destination):
            "'\(destination.path)' already exists and is not a directory."

        case let .cannotReplaceDirectory(path):
            "'\(path.path)' is a directory, and the project needs a file there."

        case let .unsafePlannedPath(path):
            "The plan contains '\(path)', which would write outside the destination."

        case let .executableNotFound(executable):
            "'\(executable)' is not installed, or not on the PATH."

        case let .commandFailed(command, exitStatus, output):
            "`\(command.displayString)` "
                + "failed with exit status \(exitStatus), while trying to: \(command.purpose)."
                + (output.isEmpty ? "" : "\n\(output.trimmingCharacters(in: .whitespacesAndNewlines))")

        case let .workspaceNotProduced(fileName):
            "pod install finished, but '\(fileName)' was not produced."

        case let .failedLeavingFiles(underlying, destination):
            "\(underlying)\n"
                + "The generated files are still in '\(destination.path)': it already existed, "
                + "so xscaffold did not remove it."
        }
    }
}
