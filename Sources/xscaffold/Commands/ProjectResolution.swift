import ArgumentParser
import Foundation
import ScaffoldCore
import ScaffoldSchema

// The steps between "what the user typed" and "a plan", shared by every
// command that needs them. Kept in one place so that `validate`, `plan` and
// `init` cannot come to different conclusions about the same file — which is
// the whole promise of `validate` running before `init`.

/// Reads and decodes a `scaffold.yml`. Used by `--config` and by `validate`,
/// which would otherwise report the same two failures in two wordings.
func readConfiguration(at path: String, reportingTo reporter: Reporter) throws -> ProjectConfiguration {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
        throw reporter.failure(.configurationParsingFailure, "Cannot read '\(path)'.")
    }

    do {
        return try ConfigurationCoder().decode(text)
    } catch {
        throw reporter.failure(.configurationParsingFailure, "\(path): \(error)")
    }
}

/// Stops the run if the configuration cannot be generated, and returns what
/// survived: the configuration wrapped as proof, and the warnings — which are
/// worth reporting and worth continuing past.
///
/// Every problem is reported rather than the first, so someone fixing five
/// mistakes runs the command once instead of five times.
func checkConfiguration(
    _ configuration: ProjectConfiguration,
    describedAs subject: String,
    reportingTo reporter: Reporter
) throws -> (validated: ValidatedConfiguration, warnings: [ValidationIssue]) {
    switch ConfigurationValidator().check(configuration) {
    case let .invalid(issues):
        throw reporter.failure(.validationFailure, "\(subject) cannot be generated.", issues: issues)
    case let .valid(validated, warnings):
        return (validated, warnings)
    }
}

/// Where the user's arguments become a project that is known to be generatable.
func resolveConfiguration(
    _ options: ProjectOptions,
    reportingTo reporter: Reporter
) throws -> (validated: ValidatedConfiguration, warnings: [ValidationIssue]) {
    let configuration = try options.configuration(reportingTo: reporter)
    let (validated, warnings) = try checkConfiguration(
        configuration,
        describedAs: "The configuration",
        reportingTo: reporter
    )

    for warning in warnings {
        reporter.note(warning.report)
    }
    return (validated, warnings)
}

func makePlan(
    for validated: ValidatedConfiguration,
    options: GenerationOptions,
    reportingTo reporter: Reporter
) throws -> GenerationPlan {
    do {
        return try GenerationPlanBuilder().makePlan(for: validated, options: options)
    } catch {
        throw reporter.failure(.templateResolutionFailure, "\(error)")
    }
}

/// Used by `plan` and by `init --dry-run`, which report the same thing under
/// their own names.
func reportPlan(for project: ProjectOptions, run: RunOptions, to reporter: Reporter) throws {
    let (validated, warnings) = try resolveConfiguration(project, reportingTo: reporter)
    let plan = try makePlan(for: validated, options: run.generationOptions, reportingTo: reporter)
    let configuration = validated.configuration
    let destination = project.destinationURL(for: configuration)
    let overwrites = plan.overwrites(at: destination)

    reporter.succeed(
        CommandOutput(
            command: reporter.command,
            exitCode: .success,
            issues: warnings,
            destination: destination.path,
            plan: PlanSummary(plan, overwrites: overwrites)
        ),
        text: "\(configuration.project.name) would be created at:\n"
            + plan.summary(at: destination, overwriting: overwrites)
    )
}

extension GenerationPlan {
    /// The shape `plan`, `init --dry-run` and `init` all report in, so that what
    /// a preview showed and what a run did can be compared line for line.
    ///
    /// The overwrites arrive as a parameter rather than being asked for here,
    /// because only the caller knows whether the run is still ahead: after
    /// writing, every planned path exists and the question answers itself
    /// wrongly. Post-write reports pass nothing.
    func summary(at destination: URL, overwriting overwrites: [String] = []) -> String {
        var lines = ["\(destination.path)", "  \(files.count) files"]
        if !overwrites.isEmpty {
            lines.append("  \(overwrites.count) existing file\(overwrites.count == 1 ? "" : "s") "
                + "will be overwritten:")
            lines += overwrites.map { "    \($0)" }
        }
        lines += commands.map { "  \($0.displayString)" }
        return lines.joined(separator: "\n")
    }
}

// The last steps of a run, shared by `init`, `new` and `generate` so they
// cannot drift: all write through the same executor, verify a build the same
// way and report success in the same shape.

/// Shows the plan and asks once more before writing, unless `--yes` — which
/// skips the question but not the summary. Shared by `new` and `generate`, so
/// the two confirmations cannot come to read differently.
func confirmed(
    _ plan: GenerationPlan,
    at destination: URL,
    using prompter: some Prompter,
    assumeYes: Bool
) -> Bool {
    prompter.show("")
    prompter.show("This will create:")
    prompter.show(plan.summary(at: destination, overwriting: plan.overwrites(at: destination)))
    guard !assumeYes else { return true }

    prompter.show("")
    prompter.show("Create it? [Y/n]:")
    guard let line = prompter.readLine() else { return false }

    let answer = line.trimmingCharacters(in: .whitespaces).lowercased()
    return answer.isEmpty || answer == "y" || answer == "yes"
}

/// A "no" or an ended input is a cancellation, not an answer of "don't
/// generate": both leave with 130 and nothing on disk. In text it says so on
/// stderr and carries no message of its own; under json the document still has
/// to appear (§11.3), agreeing with the code the process is about to exit with.
func cancelled(using prompter: some Prompter, reportingTo reporter: Reporter) -> ExitCode {
    switch reporter.format {
    case .text:
        prompter.show("Cancelled; nothing was created.")
        return ExitCode(ScaffoldExitCode.userCancelled.rawValue)
    case .json:
        return reporter.failure(.userCancelled, "Cancelled; nothing was created.")
    }
}

/// Maps a generation failure to the code it chose, for any step that lands
/// plan work on disk. One mapping, shared, so `new`'s menu and a plain write
/// cannot report the same failure under different codes.
func mappingGenerationFailure<T>(reportingTo reporter: Reporter, _ body: () throws -> T) throws -> T {
    do {
        return try body()
    } catch let error as GenerationError {
        throw reporter.failure(error.exitCode, "\(error)")
    } catch {
        throw reporter.failure(.generationFailure, "\(error)")
    }
}

/// Lays the plan on disk, mapping a generation failure to the code it chose.
func writePlan(_ plan: GenerationPlan, to destination: URL, force: Bool, reportingTo reporter: Reporter) throws {
    try mappingGenerationFailure(reportingTo: reporter) {
        try PlanExecutor().execute(plan, at: destination, force: force)
    }
}

/// The project stays if the build fails. Generation succeeded; what failed is a
/// check on top of it, and deleting the evidence would be a strange way to
/// report a compiler error.
func verifyBuild(
    of configuration: ProjectConfiguration,
    at destination: URL,
    reportingTo reporter: Reporter
) throws {
    reporter.note("Building \(configuration.project.name)…")

    do {
        try BuildValidator().validate(configuration, at: destination)
    } catch let error as BuildValidationError {
        throw reporter.failure(error.exitCode, "\(error)")
    } catch let error as GenerationError {
        // Xcode missing entirely is a missing requirement, not a failed build:
        // a different code, and a different thing to do about it.
        throw reporter.failure(error.exitCode, "\(error)")
    } catch {
        throw reporter.failure(.buildValidationFailure, "\(error)")
    }
}

func reportCreated(
    _ plan: GenerationPlan,
    warnings: [ValidationIssue],
    for configuration: ProjectConfiguration,
    at destination: URL,
    to reporter: Reporter
) {
    reporter.succeed(
        CommandOutput(
            command: reporter.command,
            exitCode: .success,
            issues: warnings,
            destination: destination.path,
            plan: PlanSummary(plan)
        ),
        text: createdText(plan, for: configuration, at: destination)
    )
}

private func createdText(
    _ plan: GenerationPlan,
    for configuration: ProjectConfiguration,
    at destination: URL
) -> String {
    var lines = ["Created \(configuration.project.name) at:", plan.summary(at: destination), ""]

    // Whether a project file exists yet is what the plan actually ran, not a
    // flag passed alongside it: the generator command is in the plan unless it
    // was skipped.
    let willGenerate = plan.commands.contains { $0.executable == configuration.generator.type.rawValue }
    guard willGenerate else {
        // Deliberately not "run `make generate`": which recipe produces the
        // project file is the generated Makefile's business, and the README that
        // has just been written says so.
        lines.append("There is no project file yet. The generated README.md says how to produce one.")
        return lines.joined(separator: "\n")
    }

    lines.append("Open it with:")
    lines.append("  open \(destination.appendingPathComponent(configuration.projectFileName).path)")
    return lines.joined(separator: "\n")
}
