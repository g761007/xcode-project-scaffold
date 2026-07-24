import Foundation
import ScaffoldSchema

/// What `new` offers once the answers are complete (§4.2): the resolved
/// configuration and its plan, shown before anything exists, then the choice —
/// generate it, keep only the scaffold.yml for review, edit a section and look
/// again, or leave nothing.
///
/// It owns the whole loop from answers to outcome — resolve, validate, plan,
/// preview, menu, and around again after an edit — so the promise each option
/// makes is kept by the type that made it, and a scripted prompter can drive
/// every path, edits included, onto a real directory.
public struct PreviewSession: Sendable {
    private let executor: PlanExecutor
    /// How Generate lands the plan — `PlanExecutor`'s parameter, carried here
    /// because the choice to force was made before the menu ever showed.
    private let force: Bool

    public init(processRunner: any ProcessRunner = SystemProcessRunner(), force: Bool = false) {
        executor = PlanExecutor(processRunner: processRunner)
        self.force = force
    }

    public enum Outcome: Sendable {
        /// The plan was executed. Carries what the loop's last round settled
        /// on, because an edit may have changed every part of it since the
        /// caller last looked.
        case generated(ValidatedConfiguration, plan: GenerationPlan, warnings: [ValidationIssue], destination: URL)
        /// Only scaffold.yml was written, at the returned location.
        case savedManifest(URL)
        /// Nothing was written.
        case cancelled
    }

    /// Shows the preview, asks until an option is chosen, and carries it out.
    /// Ended input is a cancellation, exactly as it is during the questions.
    ///
    /// The destination arrives as a function of the configuration because an
    /// edit can rename the project, and an unstated destination follows the
    /// name; the plan arrives as a function for the same reason.
    public func run(
        answers: PartialProjectConfiguration,
        destination: (ProjectConfiguration) -> URL,
        makePlan: (ValidatedConfiguration) throws -> GenerationPlan,
        using prompter: some Prompter
    ) throws -> Outcome {
        let interactive = InteractiveConfiguration()
        var answers = answers

        while true {
            let validated: ValidatedConfiguration
            let warnings: [ValidationIssue]
            do {
                answers = try interactive.resolveAnswers(answers, using: prompter)
                (validated, warnings) = checked(answers)
            } catch InteractivePromptError.cancelled {
                return .cancelled
            }

            let plan = try makePlan(validated)
            let target = destination(validated.configuration)
            show(validated.configuration, plan: plan, warnings: warnings, at: target, using: prompter)

            switch choose(using: prompter) {
            case .generate:
                try executor.execute(plan, at: target, force: force)
                return .generated(validated, plan: plan, warnings: warnings, destination: target)

            case .save:
                return try .savedManifest(saveManifest(from: plan, at: target))

            case .edit:
                guard let section = chooseSection(using: prompter) else { return .cancelled }
                do {
                    try interactive.reask(section, into: &answers, using: prompter)
                } catch InteractivePromptError.cancelled {
                    return .cancelled
                }

            case .cancel:
                return .cancelled
            }
        }
    }

    /// `resolveAnswers` has already looped until nothing is wrong, so the check
    /// cannot come back invalid; the compiler cannot know that, and the next
    /// reader should.
    private func checked(_ answers: PartialProjectConfiguration) -> (ValidatedConfiguration, [ValidationIssue]) {
        guard case let .valid(validated, warnings) = ConfigurationValidator().check(answers.resolved()) else {
            preconditionFailure("resolveAnswers returned answers that do not validate")
        }
        return (validated, warnings)
    }
}

// MARK: - The preview

extension PreviewSession {
    private func show(
        _ configuration: ProjectConfiguration,
        plan: GenerationPlan,
        warnings: [ValidationIssue],
        at destination: URL,
        using prompter: some Prompter
    ) {
        prompter.show("")
        prompter.show("Configuration Preview")
        prompter.show("")
        prompter.show("  Project:       \(configuration.project.name) (\(configuration.project.bundleIdentifier))")
        prompter.show("  Platform:      \(configuration.product.platform.displayName) "
            + "\(configuration.product.deploymentTarget), \(configuration.interface.primary.displayName)")
        prompter.show("  Architecture:  \(architectureLine(for: configuration.architecture))")
        prompter.show("  Testing:       \(configuration.testing.unit.rawValue)")
        prompter.show("  Environments:  \(environmentsLine(for: configuration.environments))")
        prompter.show("  Destination:   \(destination.path)")
        prompter.show("")
        prompter.show("  \(plan.files.count) files will be created.")

        let overwrites = plan.overwrites(at: destination)
        if !overwrites.isEmpty {
            prompter.show("  \(overwrites.count) existing file\(overwrites.count == 1 ? "" : "s") "
                + "will be overwritten:")
            overwrites.forEach { prompter.show("    \($0)") }
        }
        if !plan.commands.isEmpty {
            prompter.show("  The following commands will run:")
            plan.commands.forEach { prompter.show("    \($0.displayString)") }
        }
        for warning in warnings {
            prompter.show("  Warning \(warning.code.rawValue): \(warning.message)")
        }
    }

    private func architectureLine(for architecture: ProjectConfiguration.Architecture) -> String {
        guard architecture.pattern.hasExample else { return architecture.pattern.displayName }
        return architecture.pattern.displayName
            + (architecture.generatesExample ? ", with the example" : ", without the example")
    }

    private func environmentsLine(for environments: [Environment]) -> String {
        environments.isEmpty
            ? "none — Debug and Release"
            : environments.map(\.name).joined(separator: ", ")
    }
}

// MARK: - The menus

extension PreviewSession {
    private enum Choice {
        case generate
        case save
        case edit
        case cancel
    }

    /// Loops until the answer names an option — answer parsing, not a rule.
    /// `nil` from the prompter is ended input, and cancels.
    private func choose(using prompter: some Prompter) -> Choice {
        while true {
            prompter.show("")
            prompter.show("What next?")
            prompter.show("  1) Generate project")
            prompter.show("  2) Save scaffold.yml and exit")
            prompter.show("  3) Edit configuration")
            prompter.show("  4) Cancel")

            switch prompter.readLine().map({ $0.trimmingCharacters(in: .whitespaces) }) {
            case "1": return .generate
            case "2": return .save
            case "3": return .edit
            case "4", nil: return .cancel
            default: prompter.show("Enter a number from 1 to 4.")
            }
        }
    }

    /// Which section to edit. `nil` is ended input — the caller cancels, the
    /// same answer ended input gives everywhere else.
    private func chooseSection(using prompter: some Prompter) -> InteractiveConfiguration.Section? {
        let sections = InteractiveConfiguration.Section.allCases
        while true {
            prompter.show("")
            prompter.show("Edit which part?")
            for (index, section) in sections.enumerated() {
                prompter.show("  \(index + 1)) \(section.label)")
            }

            guard let line = prompter.readLine() else { return nil }
            let number = Int(line.trimmingCharacters(in: .whitespaces))
            if let number, sections.indices.contains(number - 1) {
                return sections[number - 1]
            }
            prompter.show("Enter a number from 1 to \(sections.count).")
        }
    }
}

// MARK: - Saving the manifest

extension PreviewSession {
    private struct PlanCarriesNoManifest: Error, CustomStringConvertible {
        var description: String {
            "The plan holds no scaffold.yml to save — which every plan should. This is a bug in xscaffold."
        }
    }

    /// Writes the plan's own scaffold.yml — the same bytes generating would
    /// have written — and nothing else. No generator runs, no dependency is
    /// installed, no repository is created.
    private func saveManifest(from plan: GenerationPlan, at destination: URL) throws -> URL {
        guard let manifest = plan.files.first(where: { $0.path == "scaffold.yml" }) else {
            throw PlanCarriesNoManifest()
        }

        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let url = destination.appendingPathComponent("scaffold.yml")
        try manifest.contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
