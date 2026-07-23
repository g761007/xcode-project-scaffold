import ArgumentParser
import Foundation
import ScaffoldCore
import ScaffoldSchema

enum OutputFormat: String, ExpressibleByArgument, CaseIterable {
    case text
    case json
}

struct OutputOptions: ParsableArguments {
    /// Named once. The root command has to recognise this flag on the raw
    /// command line, before any parsing has happened (§11.3), and two spellings
    /// of it would eventually disagree.
    static let flagName = "output"

    @Option(name: .customLong(flagName), help: "text or json.")
    var format: OutputFormat = .text
}

/// Everything a command says, in whichever form was asked for.
///
/// One type for both forms so that a command cannot report success in text and
/// forget to in JSON, and so §11.3's rules hold everywhere by construction:
/// under `--output json`, stdout carries one JSON document and nothing else,
/// while anything a person would want to read goes to stderr.
///
/// Failures included. A caller that parses stdout must be able to parse it when
/// things go wrong, which is exactly when it matters.
struct Reporter {
    let command: String
    let format: OutputFormat

    /// Takes the name from the command itself, so that the name in the help,
    /// the name in the JSON and the name in an error message cannot drift apart
    /// — there is only one of them.
    init(for command: (some ParsableCommand).Type, format: OutputFormat) {
        self.command = command.configuration.commandName ?? "xscaffold"
        self.format = format
    }

    func succeed(_ output: CommandOutput, text: @autoclosure () -> String) {
        switch format {
        case .text: print(text())
        case .json: print(json(output))
        }
    }

    /// Reports the failure and returns the error that ends the run, so that a
    /// command says `throw reporter.failure(...)` and cannot do one without the
    /// other.
    func failure(
        _ code: ScaffoldExitCode,
        _ message: String,
        issues: [ValidationIssue]? = nil,
        checks: [EnvironmentCheck]? = nil
    ) -> ExitCode {
        let output = CommandOutput(
            command: command,
            exitCode: code,
            message: message,
            issues: issues,
            checks: checks
        )

        switch format {
        case .text:
            for issue in issues ?? [] {
                printToStandardError(issue.report)
            }
            printToStandardError("Error: \(message)")
        case .json:
            print(json(output))
        }

        return ExitCode(code.rawValue)
    }

    /// Notes for the reader that are not the result — in JSON mode they would
    /// corrupt the document, so they go to stderr in both modes (§11.3).
    func note(_ message: String) {
        printToStandardError(message)
    }

    /// The promise is that stdout is always parseable JSON, so this has to
    /// survive the encoder failing too, however unlikely that is. The fallback
    /// keeps this run's own `ok` and `exitCode`: a document disagreeing with the
    /// status the process is about to exit with would be worse than no document
    /// at all.
    private func json(_ output: CommandOutput) -> String {
        guard let encoded = try? CommandOutputEncoder().encode(output) else {
            return #"{"command":"\#(command)","exitCode":\#(output.exitCode.rawValue),"#
                + #""message":"The result could not be encoded.","ok":\#(output.ok)}"#
        }
        return encoded
    }
}

/// Diagnostics go to stderr so that stdout carries only the result. §11.3 makes
/// that a rule for `--output json`; there is no reason for text mode to differ.
func printToStandardError(_ message: String) {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
}
