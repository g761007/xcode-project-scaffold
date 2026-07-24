import ArgumentParser
import Foundation
import ScaffoldCore
import ScaffoldSchema

/// The machine-dependent half of "will this work?".
///
/// Everything `validate` asks is true or false everywhere; everything here
/// depends on what is installed. Keeping them apart is what lets the same
/// `scaffold.yml` mean the same thing on two machines (§6).
struct DoctorCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check that the tools init needs are installed."
    )

    @OptionGroup var output: OutputOptions

    @Option(
        name: .customLong("config"),
        help: "A scaffold.yml to judge requirements against. Defaults to ./scaffold.yml when present."
    )
    var configurationPath: String?

    func run() throws {
        let reporter = Reporter(for: Self.self, format: output.format)
        let checks = EnvironmentDoctor().check(for: configuration(reportingTo: reporter))

        guard checks.meetsRequirements else {
            let missing = checks.filter { $0.required && !$0.found }.map(\.name)
            throw reporter.failure(
                .environmentRequirementMissing,
                "Not installed: \(missing.joined(separator: ", ")).",
                checks: checks
            )
        }

        reporter.succeed(
            CommandOutput(command: reporter.command, exitCode: .success, checks: checks),
            text: checks.map(\.report).joined(separator: "\n")
        )
    }

    /// The configuration that decides how hard to insist on CocoaPods (§9.3).
    /// A named file that cannot be read is a plain failure; an absent implicit
    /// one just means "no configuration to consult" — doctor still answers.
    private func configuration(reportingTo reporter: Reporter) -> ProjectConfiguration? {
        let path = configurationPath ?? "scaffold.yml"
        guard configurationPath != nil || FileManager.default.fileExists(atPath: path) else { return nil }
        return try? readConfiguration(at: path, reportingTo: reporter)
    }
}
