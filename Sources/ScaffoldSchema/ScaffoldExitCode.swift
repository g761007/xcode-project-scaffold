/// The exit codes from the plan's §11.4.
///
/// Part of the published contract rather than a CLI detail: a script — or the
/// Skill — that cannot tell "your configuration is wrong" from "XcodeGen is not
/// installed" has to parse English to decide what to do next. They live here so
/// that the same table is available to whatever reports them.
///
/// `1` is what is left when nothing else fits. Nothing should choose it on
/// purpose, but it has to be nameable: a failure that cannot be reported in the
/// contract's own vocabulary is worse than one that says "unexpected".
///
/// `130` (user cancelled) follows the shell convention of 128 + SIGINT (2). It
/// arrives with the interactive `new` command: answering it with Ctrl-C, or
/// ending its input, stops the run before anything is written.
public enum ScaffoldExitCode: Int32, Codable, Sendable, CaseIterable {
    case success = 0
    case unexpectedFailure = 1
    case invalidArguments = 2
    case configurationParsingFailure = 3
    case validationFailure = 4
    case templateResolutionFailure = 5
    case fileConflict = 6
    case generationFailure = 7
    case externalCommandFailure = 8
    case buildValidationFailure = 9
    case environmentRequirementMissing = 10
    case userCancelled = 130
}
