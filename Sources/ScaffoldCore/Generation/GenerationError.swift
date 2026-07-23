import Foundation
import ScaffoldSchema

/// Everything that can go wrong once a plan starts being carried out.
///
/// Parsing, validation and planning have their own error types and all happen
/// before this point, so anything here means the destination — or the machine —
/// was not what the run needed.
public enum GenerationError: Error, Equatable, Sendable {
    case destinationNotEmpty(URL)
    case destinationIsNotADirectory(URL)
    /// A directory sitting where the plan needs a file. Refused rather than
    /// removed: `--force` replaces files, and removing a directory would take
    /// everything under it with no way back (§10.2).
    case cannotReplaceDirectory(URL)
    /// A planned path that would write outside the destination.
    case unsafePlannedPath(String)
    case executableNotFound(String)
    case commandFailed(PlannedCommand, exitStatus: Int32, output: String)

    /// A failure that could not be undone, because the destination was not
    /// xscaffold's to remove (§10.2). Wraps the failure rather than replacing it
    /// so the reader still learns what went wrong, and gets told what is now in
    /// the directory they named.
    indirect case failedLeavingFiles(GenerationError, in: URL)
}

extension GenerationError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .destinationNotEmpty(destination):
            "'\(destination.path)' already exists and is not empty. "
                + "Choose an empty destination, or pass --force to write into it anyway."

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

        case let .failedLeavingFiles(underlying, destination):
            "\(underlying)\n"
                + "The generated files are still in '\(destination.path)': it already existed, "
                + "so xscaffold did not remove it."
        }
    }
}
