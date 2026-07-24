import ScaffoldSchema

/// Works out every file and command a run would produce, without touching disk.
///
/// Pure, like validation: the same configuration yields the same plan on any
/// machine. Writing the plan out is a separate step, so a failure while
/// planning leaves the destination untouched.
public struct GenerationPlanBuilder: Sendable {
    private let library = TemplateLibrary()
    private let renderer = TemplateRenderer()
    private let specBuilder = XcodeGenSpecBuilder()
    private let specEncoder = XcodeGenSpecEncoder()
    private let configurationCoder = ConfigurationCoder()

    public init() {}

    /// Takes the proof, not the configuration: `ValidatedConfiguration` can
    /// only come from the validator, so an unvalidated configuration cannot
    /// reach this entry no matter which command is calling.
    public func makePlan(
        for validated: ValidatedConfiguration,
        options: GenerationOptions = GenerationOptions()
    ) throws -> GenerationPlan {
        let configuration = validated.configuration
        return try GenerationPlan(
            files: files(for: configuration),
            commands: commands(for: configuration, options: options)
        )
    }
}

// MARK: - Files

extension GenerationPlanBuilder {
    private func files(for configuration: ProjectConfiguration) throws -> [PlannedFile] {
        let values = try placeholderValues(for: configuration)

        var files = try library.files(for: configuration).map { template in
            try PlannedFile(
                path: renderer.render(template.path, path: template.path, with: values),
                contents: renderer.render(template.contents, path: template.path, with: values)
            )
        }

        // Not templates: both are produced from the configuration itself, so
        // there is nothing for a template to add.
        try files.append(PlannedFile(
            path: "project.yml",
            contents: specEncoder.encode(specBuilder.makeSpec(for: configuration))
        ))
        try files.append(PlannedFile(
            path: "scaffold.yml",
            contents: configurationCoder.encode(configuration)
        ))

        return files.sorted { $0.path < $1.path }
    }

    private func placeholderValues(for configuration: ProjectConfiguration) throws -> [String: String] {
        let spec = specBuilder.makeSpec(for: configuration)

        return try [
            "PROJECT_NAME": configuration.project.name,
            "BUNDLE_IDENTIFIER": configuration.project.bundleIdentifier,
            "ORGANIZATION_NAME": configuration.project.organizationName,
            "DEPLOYMENT_TARGET": configuration.product.deploymentTarget,
            "LANGUAGE_MODE": configuration.language.languageMode.rawValue,
            "PLATFORM_DISPLAY_NAME": spec.platform,
            "INTERFACE_DISPLAY_NAME": configuration.interface.primary.displayName,
            "SCHEME_NAME": spec.defaultSchemeName,
            "LINT_RECIPE": makeRecipe(from: lintCommands(for: configuration)),
            "FORMAT_RECIPE": makeRecipe(from: formatCommands(for: configuration)),
            "ARCHITECTURE": library.architectureDescription(for: configuration)
        ]
    }

    /// Structural differences reach templates as values rather than as
    /// conditionals (§7.3), so a project with no linters still gets a `lint`
    /// target — one that says so instead of running a tool it never asked for.
    private func lintCommands(for configuration: ProjectConfiguration) -> [String] {
        var commands: [String] = []
        if configuration.quality.swiftformat {
            commands.append("swiftformat --lint .")
        }
        if configuration.quality.swiftlint {
            commands.append("swiftlint --strict")
        }
        return commands
    }

    private func formatCommands(for configuration: ProjectConfiguration) -> [String] {
        configuration.quality.swiftformat ? ["swiftformat ."] : []
    }

    /// Make recipes are tab-indented, and an empty recipe is a target that
    /// silently does nothing.
    private func makeRecipe(from commands: [String]) -> String {
        guard !commands.isEmpty else {
            return "\t@echo \"No linters are enabled for this project.\""
        }
        return commands.map { "\t\($0)" }.joined(separator: "\n")
    }
}

// MARK: - Commands

extension GenerationPlanBuilder {
    /// Ordered: the repository exists before anything is committed, and the
    /// commit records the sources rather than the derived `.xcodeproj`.
    private func commands(
        for configuration: ProjectConfiguration,
        options: GenerationOptions
    ) -> [PlannedCommand] {
        var commands: [PlannedCommand] = []

        if options.initializeGit {
            commands.append(PlannedCommand(
                executable: "git",
                arguments: ["init", "--initial-branch", configuration.git.defaultBranch],
                purpose: "Start a repository on \(configuration.git.defaultBranch)"
            ))
            commands.append(PlannedCommand(
                executable: "git",
                arguments: ["add", "."],
                purpose: "Stage the generated files"
            ))
            commands.append(PlannedCommand(
                executable: "git",
                arguments: ["commit", "--message", "Initial commit"],
                purpose: "Record the project as generated, before any edits"
            ))
        }

        if options.runGenerator {
            commands.append(PlannedCommand(
                executable: configuration.generator.type.rawValue,
                arguments: ["generate"],
                purpose: "Produce \(configuration.projectFileName) from project.yml"
            ))
        }

        return commands
    }
}
