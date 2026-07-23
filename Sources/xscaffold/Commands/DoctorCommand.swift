import ArgumentParser
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

    func run() throws {
        let reporter = Reporter(for: Self.self, format: output.format)
        let checks = EnvironmentDoctor().check()

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
}
