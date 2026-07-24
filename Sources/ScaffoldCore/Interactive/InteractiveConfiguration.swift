import Foundation
import ScaffoldSchema

/// What stops an interactive collection short.
public enum InteractivePromptError: Error, Equatable, Sendable {
    /// Input ended before the answers were complete — Ctrl-D, or a closed pipe.
    case cancelled
    /// A validation failure that maps to no question the prompt asked, so it
    /// cannot be fixed by re-asking. `new` reports it and stops.
    case unresolvable(ValidationIssue)
}

/// Collects a project's high-signal fields by asking, and hands back answers
/// that are known to validate.
///
/// It embeds no compatibility rules (§15): every choice is offered regardless of
/// the others, and `ConfigurationValidator` is the only thing that decides
/// whether the result can be generated. When it can't, the offending field's
/// question is asked again — which is why the questions are small methods, one
/// per field, reused by both the first pass and the re-ask.
public struct InteractiveConfiguration: Sendable {
    public init() {}

    /// Every parameter but the prompter is an answer already given on the
    /// command line, if any; a question that has its answer is not asked. The
    /// name comes as its own argument, the platform and interface together as a
    /// `--variant` (§17.1) — which is why they arrive as one.
    ///
    /// `advanced` appends the questions most runs never need (§4.2): fields
    /// that live in `scaffold.yml` and already have defaults, offered here so
    /// they can be answered without editing the file afterwards.
    ///
    /// - Throws: `InteractivePromptError`.
    public func collect(
        name initialName: String?,
        variant: Variant? = nil,
        advanced: Bool = false,
        using prompter: some Prompter
    ) throws -> PartialProjectConfiguration {
        let platform = try variant?.platform ?? askPlatform(using: prompter)
        let name = try initialName ?? askName(using: prompter)
        let bundleIdentifier = try askBundleIdentifier(for: name, using: prompter)
        let interface = try variant?.interface ?? askInterface(using: prompter)
        let (pattern, includeExample) = try askArchitecture(using: prompter)
        let environments = try askEnvironments(using: prompter)

        var answers = PartialProjectConfiguration(
            platform: platform,
            name: name,
            bundleIdentifier: bundleIdentifier,
            interface: interface,
            pattern: pattern,
            includeExample: includeExample,
            environments: environments
        )
        if advanced {
            try askAdvanced(into: &answers, using: prompter)
        }
        return try resolve(answers, using: prompter)
    }

    /// The `--advanced` questions, in schema order. Every one of them writes a
    /// `scaffold.yml` field — destination and build validation are run options,
    /// not project properties, so they stay flags (§CONTEXT: GenerationOptions
    /// never appears in scaffold.yml).
    private func askAdvanced(
        into answers: inout PartialProjectConfiguration,
        using prompter: some Prompter
    ) throws {
        answers.organizationName = try freeText("Organization name", default: nil, using: prompter)
        answers.deploymentTarget = try askDeploymentTarget(for: answers.platform, using: prompter)
        answers.unitTestFramework = try askUnitTests(using: prompter)
        answers.swiftlint = try confirm("Include SwiftLint", default: ConfigurationDefaults.swiftlint, using: prompter)
        answers.swiftformat = try confirm(
            "Include SwiftFormat", default: ConfigurationDefaults.swiftformat, using: prompter
        )
        answers.gitDefaultBranch = try freeText(
            "Git default branch", default: ConfigurationDefaults.defaultBranch, using: prompter
        )
    }
}

// MARK: - Editing a section

extension InteractiveConfiguration {
    /// One group of questions, as the preview's Edit menu offers them (§4.2).
    /// Grouped by what is asked together, so editing never re-runs the whole
    /// questionnaire.
    public enum Section: CaseIterable, Sendable {
        case project
        case platform
        case architecture
        case environments

        /// The label the Edit menu shows.
        public var label: String {
            switch self {
            case .project: "Project name and bundle identifier"
            case .platform: "Platform and interface"
            case .architecture: "Architecture"
            case .environments: "Build environments"
            }
        }
    }

    /// Asks one section's questions again, leaving every other answer as it
    /// was. The result has not been re-validated: the caller sends it through
    /// `resolveAnswers` next, which re-asks whatever the change broke.
    public func reask(
        _ section: Section,
        into answers: inout PartialProjectConfiguration,
        using prompter: some Prompter
    ) throws {
        switch section {
        case .project:
            answers.name = try askName(using: prompter)
            answers.bundleIdentifier = try askBundleIdentifier(for: answers.name, using: prompter)
        case .platform:
            answers.platform = try askPlatform(using: prompter)
            answers.interface = try askInterface(using: prompter)
        case .architecture:
            (answers.pattern, answers.includeExample) = try askArchitecture(using: prompter)
        case .environments:
            answers.environments = try askEnvironments(using: prompter)
        }
    }

    /// The validation loop, for callers that changed answers after `collect`:
    /// re-asks the question each failure points at until nothing is wrong, and
    /// returns answers that are known to validate.
    public func resolveAnswers(
        _ answers: PartialProjectConfiguration,
        using prompter: some Prompter
    ) throws -> PartialProjectConfiguration {
        try resolve(answers, using: prompter)
    }
}

// MARK: - The validation loop

extension InteractiveConfiguration {
    /// Re-asks the question a validation error points at until nothing is wrong.
    /// Every offered choice is valid on its own, so what reaches here is a bad
    /// free-text field or a combination the validator rejects (mvvm-c on
    /// SwiftUI); either way the fix is to answer one question again.
    private func resolve(
        _ answers: PartialProjectConfiguration,
        using prompter: some Prompter
    ) throws -> PartialProjectConfiguration {
        var answers = answers
        while let issue = firstError(in: answers) {
            prompter.show("")
            prompter.show(issue.message)
            if let suggestion = issue.suggestion {
                prompter.show(suggestion)
            }
            try reask(for: issue, into: &answers, using: prompter)
        }
        return answers
    }

    private func firstError(in answers: PartialProjectConfiguration) -> ValidationIssue? {
        ConfigurationValidator().validate(answers.resolved()).first { $0.severity == .error }
    }

    private func reask(
        for issue: ValidationIssue,
        into answers: inout PartialProjectConfiguration,
        using prompter: some Prompter
    ) throws {
        switch issue.path {
        case "project.name":
            answers.name = try askName(using: prompter)
        case "project.bundleIdentifier":
            answers.bundleIdentifier = try askBundleIdentifier(for: answers.name, using: prompter)
        case "product.platform":
            answers.platform = try askPlatform(using: prompter)
        case "product.deploymentTarget":
            answers.deploymentTarget = try askDeploymentTarget(for: answers.platform, using: prompter)
        case "testing.unit":
            answers.unitTestFramework = try askUnitTests(using: prompter)
        case "interface.primary", "interface.lifecycle":
            answers.interface = try askInterface(using: prompter)
        case "architecture.pattern", "architecture.includeExample":
            (answers.pattern, answers.includeExample) = try askArchitecture(using: prompter)
        case let path? where path.hasPrefix("environments"):
            answers.environments = try askEnvironments(using: prompter)
        default:
            throw InteractivePromptError.unresolvable(issue)
        }
    }
}

// MARK: - The questions

extension InteractiveConfiguration {
    private func askName(using prompter: some Prompter) throws -> String {
        try freeText("Project name", default: nil, using: prompter)
    }

    private func askBundleIdentifier(for name: String, using prompter: some Prompter) throws -> String {
        try freeText("Bundle identifier", default: Preset.bundleIdentifier(for: name), using: prompter)
    }

    /// Every interface is offered on every platform. A pairing the platform does
    /// not allow (UIKit on macOS, AppKit on iOS) is left to the validator, which
    /// re-asks this question — the prompt holds no compatibility rule (§15).
    private func askPlatform(using prompter: some Prompter) throws -> ApplePlatform {
        try choice("Platform", [("iOS", ApplePlatform.iOS), ("macOS", .macOS)], using: prompter)
    }

    private func askInterface(using prompter: some Prompter) throws -> UIFramework {
        try choice(
            "Interface",
            [("UIKit", UIFramework.uiKit), ("SwiftUI", .swiftUI), ("AppKit", .appKit)],
            using: prompter
        )
    }

    /// The example question follows from the architecture: a pattern with no
    /// example has nothing to include, so `minimal` is never asked about it.
    private func askArchitecture(using prompter: some Prompter) throws -> (ArchitecturePattern, Bool?) {
        let pattern = try choice("Architecture", [
            ("Minimal", ArchitecturePattern.minimal),
            ("MVVM", .mvvm),
            ("MVVM-C", .mvvmCoordinator)
        ], using: prompter)

        let includeExample = pattern.hasExample
            ? try confirm("Include the example", default: true, using: prompter)
            : nil
        return (pattern, includeExample)
    }

    private func askDeploymentTarget(for platform: ApplePlatform, using prompter: some Prompter) throws -> String {
        try freeText(
            "Deployment target",
            default: ConfigurationDefaults.deploymentTarget(for: platform),
            using: prompter
        )
    }

    /// Every framework the schema knows is offered, including ones this
    /// version does not generate yet — the validator says so and the question
    /// is asked again, the same as every other unsupported choice (§15).
    private func askUnitTests(using prompter: some Prompter) throws -> UnitTestFramework {
        try choice("Unit tests", [
            ("Swift Testing", UnitTestFramework.swiftTesting),
            ("XCTest", .xctest),
            ("None", .disabled)
        ], using: prompter)
    }

    private func askEnvironments(using prompter: some Prompter) throws -> [Environment] {
        try choice("Build environments", [
            ("None — just Debug and Release", [Environment]()),
            ("Standard — development, staging, production", PartialProjectConfiguration.standardEnvironments)
        ], using: prompter)
    }
}

// MARK: - Primitives

extension InteractiveConfiguration {
    private func freeText(_ label: String, default fallback: String?, using prompter: some Prompter) throws -> String {
        prompter.show(fallback.map { "\(label) [\($0)]:" } ?? "\(label):")
        guard let line = prompter.readLine() else { throw InteractivePromptError.cancelled }

        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty, let fallback {
            return fallback
        }
        return trimmed
    }

    /// Loops until the answer names one of the options. That is answer parsing,
    /// not a compatibility rule — every option shown is a choice the user is
    /// allowed to make.
    private func choice<Value>(
        _ label: String,
        _ options: [(label: String, value: Value)],
        using prompter: some Prompter
    ) throws -> Value {
        while true {
            prompter.show("\(label):")
            for (index, option) in options.enumerated() {
                prompter.show("  \(index + 1)) \(option.label)")
            }

            guard let line = prompter.readLine() else { throw InteractivePromptError.cancelled }
            if let number = Int(line.trimmingCharacters(in: .whitespaces)), options.indices.contains(number - 1) {
                return options[number - 1].value
            }
            prompter.show("Enter a number from 1 to \(options.count).")
        }
    }

    private func confirm(_ label: String, default fallback: Bool, using prompter: some Prompter) throws -> Bool {
        prompter.show("\(label) \(fallback ? "[Y/n]" : "[y/N]"):")
        guard let line = prompter.readLine() else { throw InteractivePromptError.cancelled }

        let answer = line.trimmingCharacters(in: .whitespaces).lowercased()
        if answer.isEmpty {
            return fallback
        }
        return answer == "y" || answer == "yes"
    }
}
