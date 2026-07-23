/// Everything a run would do, worked out before anything is written.
///
/// `plan` and `init --dry-run` print this; `init` executes it. Nothing writes
/// to the destination without going through a plan first, so a failure part way
/// through can leave the destination untouched rather than half-built.
public struct GenerationPlan: Codable, Equatable, Sendable {
    /// In the order they will be written. Paths are relative to the
    /// destination directory and always use `/`.
    public var files: [PlannedFile]

    /// Run after every file is in place, in order.
    public var commands: [PlannedCommand]

    public init(files: [PlannedFile], commands: [PlannedCommand]) {
        self.files = files
        self.commands = commands
    }
}

public struct PlannedFile: Codable, Equatable, Sendable {
    public var path: String
    public var contents: String

    public init(path: String, contents: String) {
        self.path = path
        self.contents = contents
    }
}

public struct PlannedCommand: Codable, Equatable, Sendable {
    public var executable: String
    public var arguments: [String]

    /// Shown when the plan is printed, and in the error if the command fails.
    /// A reader should not have to know what `xcodegen generate` is for.
    public var purpose: String

    public init(executable: String, arguments: [String], purpose: String) {
        self.executable = executable
        self.arguments = arguments
        self.purpose = purpose
    }
}
