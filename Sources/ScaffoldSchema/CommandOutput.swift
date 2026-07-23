/// What every command writes to stdout under `--output json`.
///
/// One shape for every command and for both outcomes (§11.3), because the
/// alternative is a caller that must know which command it ran before it can
/// tell success from failure. `ok` and `exitCode` are always there; everything
/// else is present when that command has it to say and omitted when it does
/// not.
///
/// A failure produces this too — never a bare stack trace or a half-written
/// document — so a caller can always parse what it gets.
public struct CommandOutput: Codable, Equatable, Sendable {
    /// Derived from `exitCode` rather than passed in, so that no caller can
    /// produce a document claiming success while the process exits 4.
    public var ok: Bool
    /// The command that produced this, so a log of several is readable.
    public var command: String
    /// Encoded as the number a caller branches on, not as a case name: the
    /// enum's raw value *is* the wire format.
    public var exitCode: ScaffoldExitCode

    /// One sentence, on failure. Absent on success.
    public var message: String?

    /// From `validate`, and from any command that refused a configuration.
    /// Present and empty means "checked, nothing found"; absent means "not
    /// checked".
    public var issues: [ValidationIssue]?

    /// Where the project is, or would be. Absolute.
    public var destination: String?

    /// From `plan`, `init --dry-run` and `init`.
    public var plan: PlanSummary?

    /// From `doctor`.
    public var checks: [EnvironmentCheck]?

    public init(
        command: String,
        exitCode: ScaffoldExitCode,
        message: String? = nil,
        issues: [ValidationIssue]? = nil,
        destination: String? = nil,
        plan: PlanSummary? = nil,
        checks: [EnvironmentCheck]? = nil
    ) {
        ok = exitCode == .success
        self.command = command
        self.exitCode = exitCode
        self.message = message
        self.issues = issues
        self.destination = destination
        self.plan = plan
        self.checks = checks
    }
}

/// A `GenerationPlan` as a caller wants to read it: which files, how big, and
/// what would run.
///
/// File *contents* are deliberately absent. The plan for a bare project is some
/// forty kilobytes of source, and nothing a caller does with this — showing a
/// summary, deciding whether to go ahead — needs it. A caller that wants the
/// contents wants the generated project.
public struct PlanSummary: Codable, Equatable, Sendable {
    public var files: [File]
    public var commands: [PlannedCommand]

    public init(files: [File], commands: [PlannedCommand]) {
        self.files = files
        self.commands = commands
    }

    public struct File: Codable, Equatable, Sendable {
        /// Relative to the destination, always with `/`.
        public var path: String
        /// UTF-8 bytes, so a caller can tell an empty file from a full one.
        public var bytes: Int

        public init(path: String, bytes: Int) {
            self.path = path
            self.bytes = bytes
        }
    }
}

extension PlanSummary {
    public init(_ plan: GenerationPlan) {
        self.init(
            files: plan.files.map { File(path: $0.path, bytes: $0.contents.utf8.count) },
            commands: plan.commands
        )
    }
}

/// One thing `doctor` looked for.
public struct EnvironmentCheck: Codable, Equatable, Sendable {
    public var name: String
    /// Whether a default `init` cannot proceed without it. Optional tools are
    /// reported so that a project that generates but cannot be linted is not a
    /// surprise later.
    public var required: Bool
    public var found: Bool
    /// Where it is and what version, or what to do about it missing.
    public var detail: String?

    public init(name: String, required: Bool, found: Bool, detail: String? = nil) {
        self.name = name
        self.required = required
        self.found = found
        self.detail = detail
    }
}
