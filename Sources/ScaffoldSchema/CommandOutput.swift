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
    ///
    /// Always the same sentence as `error.message`, and structurally so: the
    /// only initialiser that sets it is the failure one, which takes it from
    /// the error. Kept beside `error` rather than removed at 1.0 because it is
    /// the key a caller that does not model errors reads, and it has been in
    /// every `--output json` document since v0.2 — `error` arrived in v0.8.
    /// Removing the older and more widely read of two keys carrying the same
    /// string costs those callers and buys tidiness.
    public private(set) var message: String?

    /// Where the run was when it failed (§23). Absent on success, and absent
    /// on the one failure that cannot know — see `ScaffoldErrorCode.phase`.
    public var phase: ScaffoldPhase?

    /// What went wrong, in the terms §23 requires: a code to branch on, an
    /// exit code, something to do about it, and the command or path it is
    /// about. Absent on success.
    public var error: ScaffoldError?

    /// From `validate`, and from any command that refused a configuration.
    /// Present and empty means "checked, nothing found"; absent means "not
    /// checked".
    public var issues: [ValidationIssue]?

    /// Where the project is, or would be. Absolute.
    public var destination: String?

    /// From `plan`, `init --dry-run` and `init`.
    public var plan: PlanSummary?

    /// The configuration with every default resolved — what an unanswered field
    /// will actually be. From `plan --resolved-config`, which answers it about a
    /// file, and from `config example`, which answers it about a preset.
    public var resolvedConfiguration: ProjectConfiguration?

    /// From `doctor`.
    public var checks: [EnvironmentCheck]?

    /// From `capabilities` (§19): what this binary can generate. A JSON value
    /// here rather than in core, because the schema owns the wire.
    public var capabilities: CapabilitiesDocument?

    /// The success form. It takes no `message`: a sentence with no error behind
    /// it would be a `message` that `error.message` does not match, and that
    /// pair is the whole reason both keys can exist.
    public init(
        command: String,
        exitCode: ScaffoldExitCode,
        issues: [ValidationIssue]? = nil,
        destination: String? = nil,
        plan: PlanSummary? = nil,
        resolvedConfiguration: ProjectConfiguration? = nil,
        checks: [EnvironmentCheck]? = nil,
        capabilities: CapabilitiesDocument? = nil
    ) {
        ok = exitCode == .success
        self.command = command
        self.exitCode = exitCode
        self.issues = issues
        self.destination = destination
        self.plan = plan
        self.resolvedConfiguration = resolvedConfiguration
        self.checks = checks
        self.capabilities = capabilities
    }

    /// The failure form (§23). Everything that says *what went wrong* comes
    /// from the one error, so a document cannot claim a code that disagrees
    /// with its exit status, or carry a message that is not the error's.
    ///
    /// `phase` defaults to the code's own, and is passed only where the same
    /// code can arrive from more than one stage.
    public init(
        command: String,
        error: ScaffoldError,
        phase: ScaffoldPhase? = nil,
        issues: [ValidationIssue]? = nil,
        checks: [EnvironmentCheck]? = nil
    ) {
        self.init(
            command: command,
            exitCode: error.exitCode,
            issues: issues,
            checks: checks
        )
        message = error.message
        self.phase = phase ?? error.code.phase
        self.error = error
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

    /// Planned paths that already exist at the destination and would be
    /// replaced (§13.3). Present only when there are any — an absent key and
    /// "nothing would be overwritten" are the same statement.
    public var overwrites: [String]?

    public init(files: [File], commands: [PlannedCommand], overwrites: [String]? = nil) {
        self.files = files
        self.commands = commands
        self.overwrites = (overwrites?.isEmpty == false) ? overwrites : nil
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
    public init(_ plan: GenerationPlan, overwrites: [String]? = nil) {
        self.init(
            files: plan.files.map { File(path: $0.path, bytes: $0.contents.utf8.count) },
            commands: plan.commands,
            overwrites: overwrites
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
