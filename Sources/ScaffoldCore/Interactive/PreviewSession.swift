import Foundation
import ScaffoldSchema

/// What `new` offers once the answers are complete (§4.2): the resolved
/// configuration and its plan, shown before anything exists, then the choice —
/// generate it, keep only the scaffold.yml for review, or leave nothing.
///
/// It asks *and* acts, so the promise each option makes — "Cancel leaves
/// nothing", "Save writes one file" — is kept by the same type that made it,
/// and a scripted prompter can drive every path onto a real directory.
public struct PreviewSession: Sendable {
    private let executor: PlanExecutor
    /// How Generate lands the plan — `PlanExecutor`'s parameter, carried here
    /// because the choice to force was made before the menu ever showed.
    private let force: Bool

    public init(processRunner: any ProcessRunner = SystemProcessRunner(), force: Bool = false) {
        executor = PlanExecutor(processRunner: processRunner)
        self.force = force
    }

    public enum Outcome: Equatable, Sendable {
        /// The plan was executed; the project is at the destination.
        case generated
        /// Only scaffold.yml was written, at the returned location.
        case savedManifest(URL)
        /// Nothing was written.
        case cancelled
    }

    /// Shows the preview, asks until an option is chosen, and carries it out.
    /// Ended input is a cancellation, exactly as it is during the questions.
    ///
    /// Takes a `ValidatedConfiguration` by design (§26): what is previewed is
    /// what would generate, and an unvalidated configuration can do neither.
    public func run(
        _ plan: GenerationPlan,
        for validated: ValidatedConfiguration,
        warnings: [ValidationIssue],
        at destination: URL,
        using prompter: some Prompter
    ) throws -> Outcome {
        show(validated.configuration, plan: plan, warnings: warnings, at: destination, using: prompter)

        switch choose(using: prompter) {
        case .generate:
            try executor.execute(plan, at: destination, force: force)
            return .generated
        case .save:
            return try .savedManifest(saveManifest(from: plan, at: destination))
        case .cancel:
            return .cancelled
        }
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

// MARK: - The menu

extension PreviewSession {
    private enum Choice {
        case generate
        case save
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
            prompter.show("  3) Cancel")

            switch prompter.readLine().map({ $0.trimmingCharacters(in: .whitespaces) }) {
            case "1": return .generate
            case "2": return .save
            case "3", nil: return .cancel
            default: prompter.show("Enter a number from 1 to 3.")
            }
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
