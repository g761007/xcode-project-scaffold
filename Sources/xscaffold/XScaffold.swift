import ArgumentParser
import Foundation
import ScaffoldCore
import ScaffoldSchema

@main
struct XScaffold: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "xscaffold",
        abstract: "Create a new Xcode project reproducibly, from a single version-controlled configuration file.",
        version: ScaffoldVersion.current,
        subcommands: [
            InitCommand.self,
            NewCommand.self,
            GenerateCommand.self,
            ValidateCommand.self,
            PlanCommand.self,
            DoctorCommand.self
        ]
    )
}

// MARK: - Exiting

extension XScaffold {
    /// Replaces ArgumentParser's own `main()` for one reason: exit codes.
    ///
    /// §11.4 assigns `2` to invalid arguments, but ArgumentParser answers its
    /// own parse failures with `EX_USAGE` (64). Two codes for one meaning would
    /// leave a caller matching on both and guessing which is which, so the one
    /// that is ours wins and everything else passes through untouched.
    ///
    /// Help and `--version` are requests rather than failures: they keep
    /// stdout and exit 0, exactly as they did before.
    static func main() {
        do {
            var command = try parseAsRoot()
            try command.run()
        } catch {
            stop(with: error)
        }
    }

    private static func stop(with error: any Error) -> Never {
        let code = exitCode(for: error)
        let message = fullMessage(for: error)

        guard code != .success else {
            if !message.isEmpty {
                print(message)
            }
            Foundation.exit(ScaffoldExitCode.success.rawValue)
        }

        // ArgumentParser's own parse failures are the ones §11.4 renames;
        // anything a command threw already carries the code it chose.
        let reported = code == .validationFailure
            ? ScaffoldExitCode.invalidArguments
            : ScaffoldExitCode(rawValue: code.rawValue) ?? .unexpectedFailure

        // A command that has already reported throws a bare ExitCode, which
        // carries no message; anything with one has not been reported yet.
        if !message.isEmpty {
            report(message, as: reported)
        }
        Foundation.exit(reported.rawValue)
    }

    /// §11.3 promises that stdout under `--output json` is always a JSON
    /// document — including when the arguments were wrong, which is before any
    /// command exists to know that json was asked for. Hence reading it back
    /// off the command line: the promise has to hold here too, or a caller has
    /// to be ready for output it cannot parse.
    private static func report(_ message: String, as code: ScaffoldExitCode) {
        guard jsonWasRequested else {
            printToStandardError(message)
            return
        }

        let output = CommandOutput(command: attemptedCommand, exitCode: code, message: message)
        print((try? CommandOutputEncoder().encode(output)) ?? "")
    }

    /// Which subcommand the user was reaching for, matched against the real
    /// names rather than "the first thing without a dash" — the latter answers
    /// `json` for `xscaffold --output json --bogus`.
    private static var attemptedCommand: String {
        // Written as a closure rather than `compactMap(\.configuration.commandName)`:
        // that key path opens an existential metatype, which crashes SILGen on
        // Swift 6.3.1.
        var names: Set<String> = []
        for subcommand in configuration.subcommands {
            if let name = subcommand.configuration.commandName {
                names.insert(name)
            }
        }
        return CommandLine.arguments.first(where: names.contains) ?? "xscaffold"
    }

    private static var jsonWasRequested: Bool {
        let flag = "--\(OutputOptions.flagName)"
        let json = OutputFormat.json.rawValue
        let arguments = CommandLine.arguments

        if arguments.contains("\(flag)=\(json)") {
            return true
        }
        guard let index = arguments.firstIndex(of: flag) else { return false }
        return arguments.indices.contains(index + 1) && arguments[index + 1] == json
    }
}
