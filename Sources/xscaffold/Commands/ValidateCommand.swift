import ArgumentParser
import ScaffoldCore
import ScaffoldSchema

/// Answers "would this generate?" without generating anything.
///
/// Pure by construction, because the validator is (§6): the same `scaffold.yml`
/// is valid or invalid identically on every machine. Whether *this* machine can
/// carry it out is `doctor`'s question.
struct ValidateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Check a scaffold.yml. Writes nothing."
    )

    @Argument(help: "Path to a scaffold.yml.")
    var path: String

    @OptionGroup var output: OutputOptions

    func run() throws {
        let reporter = Reporter(for: Self.self, format: output.format)
        let configuration = try readConfiguration(at: path, reportingTo: reporter)
        let (_, warnings) = try checkConfiguration(configuration, describedAs: path, reportingTo: reporter)

        reporter.succeed(
            CommandOutput(command: reporter.command, exitCode: .success, issues: warnings),
            text: report(warnings)
        )
    }

    /// Warnings do not stop a run, so they belong with the result rather than
    /// on stderr with the failures.
    private func report(_ warnings: [ValidationIssue]) -> String {
        guard !warnings.isEmpty else { return "\(path) is valid." }

        return (["\(path) is valid, with \(warnings.count) warning(s):"]
            + warnings.map(\.report)).joined(separator: "\n")
    }
}
