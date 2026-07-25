/// Where a run was when it failed (§23).
///
/// §7.1 also lists a set of names, but those are the states an interactive
/// session's value passes through — `failed` among them. Reporting `failed` as
/// the phase of a failure says nothing, so the vocabulary here is the one §23's
/// own example uses: the stage of work that was under way. ADR-0009 records the
/// choice.
///
/// The distinctions are the ones that change what a reader does next. Whether
/// the destination now has files in it, whether a tool needs installing, and
/// whether the configuration or the machine is at fault are all answered by
/// this field before the message is read.
public enum ScaffoldPhase: String, Codable, Sendable, CaseIterable {
    /// Before any command ran: the arguments themselves were wrong.
    case invocation
    /// Reading `scaffold.yml` and turning it into a configuration.
    case configuration
    /// Checking that configuration.
    case validation
    /// Working out the files and commands. Still nothing on disk.
    case planning
    /// Waiting for the user to approve the plan.
    case confirmation
    /// Writing the planned files, and the git commands over them.
    case generation
    /// Running the generator over `project.yml`.
    case projectGeneration
    /// Running Bundler and CocoaPods.
    case dependencyInstallation
    /// Building the generated project, for `--validate-build`.
    case buildValidation
    /// `doctor` looking for the tools a run needs.
    case environmentCheck
}

/// Every failure this binary can report, as the name a caller branches on.
///
/// The list is §23's, with two deliberate differences.
///
/// Codes §23 names that are **not** here have no failure path that could emit
/// them: `CONFIGURATION_UNSUPPORTED` (a `ValidationCode` in the `XS0xxx` range
/// says this already, and arrives inside `CONFIGURATION_INVALID`'s issues),
/// `DEPENDENCY_CONFLICT` and `INVALID_POD_CONFIGURATION` (validation's job,
/// same place), `PODFILE_GENERATION_FAILED` (rendering a Podfile cannot fail —
/// it is string assembly over a validated configuration),
/// `PACKAGE_RESOLUTION_FAILED` (xscaffold never resolves packages; Xcode does,
/// after generation), `SCHEMA_VERSION_UNSUPPORTED` (nothing checks the
/// version yet — issue #115) and `GENERATION_ROLLBACK_FAILED` (a
/// failed rollback keeps the underlying failure's code, so that what a caller
/// branches on stays "why it failed"; the leftover directory is in `path`).
/// A code nothing can emit is dead the same way an unreachable `ValidationCode`
/// is, and was dropped for the same reason.
///
/// Codes here that §23 does not name are failure paths that exist and had no
/// name: wrong arguments, an unreadable or malformed configuration, a
/// destination that is not a directory, and the two catch-alls.
public enum ScaffoldErrorCode: String, Codable, Sendable, CaseIterable {
    case invalidArguments = "INVALID_ARGUMENTS"
    case configurationUnreadable = "CONFIGURATION_UNREADABLE"
    case configurationMalformed = "CONFIGURATION_MALFORMED"
    case configurationInvalid = "CONFIGURATION_INVALID"
    case templateConflict = "TEMPLATE_CONFLICT"
    case templateResolutionFailed = "TEMPLATE_RESOLUTION_FAILED"
    case outputDirectoryNotEmpty = "OUTPUT_DIRECTORY_NOT_EMPTY"
    case outputDirectoryHasProject = "OUTPUT_DIRECTORY_HAS_PROJECT"
    case outputPathNotADirectory = "OUTPUT_PATH_NOT_A_DIRECTORY"
    case outputPathBlockedByDirectory = "OUTPUT_PATH_BLOCKED_BY_DIRECTORY"
    case unsafePlannedPath = "UNSAFE_PLANNED_PATH"
    case xcodegenNotInstalled = "XCODEGEN_NOT_INSTALLED"
    case cocoapodsNotInstalled = "COCOAPODS_NOT_INSTALLED"
    case bundlerNotInstalled = "BUNDLER_NOT_INSTALLED"
    case executableNotFound = "EXECUTABLE_NOT_FOUND"
    case environmentRequirementMissing = "ENVIRONMENT_REQUIREMENT_MISSING"
    case xcodegenFailed = "XCODEGEN_FAILED"
    case podInstallFailed = "POD_INSTALL_FAILED"
    case commandFailed = "COMMAND_FAILED"
    case workspaceNotGenerated = "WORKSPACE_NOT_GENERATED"
    case generationFailed = "GENERATION_FAILED"
    case buildValidationFailed = "BUILD_VALIDATION_FAILED"
    case generationCancelled = "GENERATION_CANCELLED"
    case unexpectedFailure = "UNEXPECTED_FAILURE"
}

extension ScaffoldErrorCode {
    /// One code, one exit code. Written as an exhaustive switch so that adding
    /// a code makes the compiler ask what it exits with — a failure that
    /// silently inherits someone else's number is one a script branches on
    /// wrongly.
    public var exitCode: ScaffoldExitCode {
        switch self {
        case .invalidArguments: .invalidArguments
        case .configurationUnreadable, .configurationMalformed: .configurationParsingFailure
        case .configurationInvalid: .validationFailure
        case .templateConflict, .templateResolutionFailed: .templateResolutionFailure
        case .outputDirectoryNotEmpty, .outputDirectoryHasProject,
             .outputPathNotADirectory, .outputPathBlockedByDirectory: .fileConflict
        case .unsafePlannedPath, .workspaceNotGenerated, .generationFailed: .generationFailure
        case .xcodegenNotInstalled, .cocoapodsNotInstalled, .bundlerNotInstalled,
             .executableNotFound, .environmentRequirementMissing: .environmentRequirementMissing
        case .xcodegenFailed, .podInstallFailed, .commandFailed: .externalCommandFailure
        case .buildValidationFailed: .buildValidationFailure
        case .generationCancelled: .userCancelled
        case .unexpectedFailure: .unexpectedFailure
        }
    }

    /// The stage this code belongs to, when the code alone settles it.
    ///
    /// `nil` for `unexpectedFailure`, which is what is left when nothing else
    /// fits: it can arrive from anywhere, and naming a phase for it would be a
    /// guess printed as a fact. `executableNotFound` has a default here and is
    /// overridden per failure, because which stage was missing its tool depends
    /// on which tool.
    public var phase: ScaffoldPhase? {
        switch self {
        case .invalidArguments: .invocation
        case .configurationUnreadable, .configurationMalformed: .configuration
        case .configurationInvalid: .validation
        case .templateConflict, .templateResolutionFailed: .planning
        case .generationCancelled: .confirmation
        case .outputDirectoryNotEmpty, .outputDirectoryHasProject, .outputPathNotADirectory,
             .outputPathBlockedByDirectory, .unsafePlannedPath, .generationFailed,
             .commandFailed, .executableNotFound: .generation
        case .xcodegenNotInstalled, .xcodegenFailed: .projectGeneration
        case .cocoapodsNotInstalled, .bundlerNotInstalled, .podInstallFailed,
             .workspaceNotGenerated: .dependencyInstallation
        case .buildValidationFailed: .buildValidation
        case .environmentRequirementMissing: .environmentCheck
        case .unexpectedFailure: nil
        }
    }

    /// What to do about it (§23). Attached to the code rather than to each
    /// failure so that there is exactly one of them per code and a test can
    /// walk the list: a code with no suggestion is a user pasting a log
    /// somewhere and waiting.
    ///
    /// Anything that varies with the run — which file, which directory, which
    /// command — belongs in the message, which has the values. This says what
    /// to do, in the same words every time.
    public var recoverySuggestion: String {
        switch self {
        case .invalidArguments:
            "Run `xscaffold <command> --help` to see what the command accepts."
        case .configurationUnreadable:
            "Check the path. `xscaffold config example > scaffold.yml` writes one to start from."
        case .configurationMalformed:
            "Fix the field named above. `xscaffold config example` prints a document with the right shape."
        case .configurationInvalid:
            "Fix the issues listed above; each names the field and what it expects."
        case .templateConflict:
            "Turn off one of the features claiming the file. If none of them is yours to turn off, "
                + "this is a bug in xscaffold — please report it."
        case .templateResolutionFailed:
            "Check that the variant and architecture are ones `xscaffold capabilities` lists."
        case .outputDirectoryNotEmpty:
            "Choose an empty destination, or pass --force to write into this one anyway."
        case .outputDirectoryHasProject:
            "Choose a destination with no project in it. xscaffold creates projects and never updates one."
        case .outputPathNotADirectory:
            "Choose a destination that is a directory, or move the file in the way."
        case .outputPathBlockedByDirectory:
            "Move the directory out of the way and run this again."
        case .unsafePlannedPath:
            "This is a bug in xscaffold — please report it with the configuration that produced it."
        case .xcodegenNotInstalled:
            "Install it with `brew install xcodegen`, then run `xscaffold doctor`."
        case .cocoapodsNotInstalled:
            "Install it with `brew install cocoapods`, then run `xscaffold doctor`."
        case .bundlerNotInstalled:
            "Install it with `gem install bundler`, then run `xscaffold doctor`."
        case .executableNotFound:
            "Install it and make sure it is on the PATH. `xscaffold doctor` lists what a run needs."
        case .environmentRequirementMissing:
            "Install what is reported missing above, then run this again."
        case .xcodegenFailed:
            "Run `xcodegen generate` in the destination to see the full output."
        case .podInstallFailed:
            "Run the install again with --verbose in the destination to see what CocoaPods decided."
        case .commandFailed:
            "Run the command shown above in the destination to see the full output."
        case .workspaceNotGenerated:
            "Run the install again in the destination: a Podfile that integrates nothing produces no workspace."
        case .generationFailed:
            "Remove the destination and run this again. If it fails the same way, please report it."
        case .buildValidationFailed:
            "Open the generated project and build it to see the compiler's full output."
        case .generationCancelled:
            "Nothing was created. Run the command again when you are ready."
        case .unexpectedFailure:
            "Please report this, with the message above and the command that produced it."
        }
    }
}

/// The `error` of a failed `CommandOutput` (§23).
///
/// `exitCode` and `recoverySuggestion` are derived from `code` rather than
/// passed in, for the reason `CommandOutput.ok` is derived from its exit code:
/// no caller can produce a document whose code and exit status disagree, or one
/// that names a failure and then has nothing to say about it.
public struct ScaffoldError: Codable, Equatable, Sendable {
    /// The name to branch on.
    public var code: ScaffoldErrorCode
    /// One sentence, with the values in it: which file, which directory.
    public var message: String
    public var exitCode: ScaffoldExitCode
    public var recoverySuggestion: String

    /// The external command, when one ran and failed. As it would be typed.
    public var command: String?

    /// The file or directory the failure is about: the destination that was
    /// not empty, the field's file, the path claimed twice.
    public var path: String?

    public init(code: ScaffoldErrorCode, message: String, command: String? = nil, path: String? = nil) {
        self.code = code
        self.message = message
        exitCode = code.exitCode
        recoverySuggestion = code.recoverySuggestion
        self.command = command
        self.path = path
    }
}
