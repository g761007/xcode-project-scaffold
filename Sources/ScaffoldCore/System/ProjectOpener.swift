import Foundation
import ScaffoldSchema

/// Opens a generated project in whatever the system associates with it —
/// `--open`'s one job. Through `ProcessRunner` like every other subprocess, so
/// a test can assert what would be launched without launching Xcode.
public struct ProjectOpener: Sendable {
    private let processRunner: any ProcessRunner

    public init(processRunner: any ProcessRunner = SystemProcessRunner()) {
        self.processRunner = processRunner
    }

    /// What failed, kept apart from generation errors: the project exists and
    /// is fine — only the courtesy of opening it did not happen.
    public struct CouldNotOpen: Error, CustomStringConvertible {
        public let path: String
        public var description: String {
            "The project was created, but opening '\(path)' failed."
        }
    }

    /// Opens the project file the generator produced at `destination`.
    public func open(_ configuration: ProjectConfiguration, at destination: URL) throws {
        let path = destination.appendingPathComponent(configuration.projectFileName).path
        let result = try processRunner.run(ProcessInvocation(
            executable: "open",
            arguments: [path],
            workingDirectory: destination
        ))
        guard result.succeeded else {
            throw CouldNotOpen(path: path)
        }
    }
}
