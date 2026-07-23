import ArgumentParser
import Foundation

/// The exit codes from §11.4.
///
/// Part of the CLI's contract, not decoration: a script — or the Skill — that
/// cannot tell "your configuration is wrong" from "XcodeGen is not installed"
/// has to parse English to decide what to do next.
///
/// Only the codes a command can actually produce are listed. `9` (build
/// validation) and `130` (user cancelled) arrive with the flags that cause them.
enum ScaffoldExitCode: Int32 {
    case invalidArguments = 2
    case configurationParsingFailure = 3
    case validationFailure = 4
    case templateResolutionFailure = 5
    case fileConflict = 6
    case generationFailure = 7
    case externalCommandFailure = 8
    case environmentRequirementMissing = 10
}

/// Reports `message` on stderr and returns the error that stops the run.
///
/// Both halves of "fail with this code, and say why" in one call, so a command
/// cannot do one and forget the other. ArgumentParser prints nothing for a
/// thrown `ExitCode`, and gives every other error exit status 1 — so a command
/// that wants both a message and a code has to write the message itself.
func failure(_ code: ScaffoldExitCode, _ message: String) -> ExitCode {
    printToStandardError("Error: \(message)")
    return ExitCode(code.rawValue)
}

/// Diagnostics go to stderr so that stdout carries only the result. §11.3 makes
/// that a rule for `--output json`; there is no reason for text mode to differ.
func printToStandardError(_ message: String) {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
}
