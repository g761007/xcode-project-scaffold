import ScaffoldSchema

/// The answers `new` collects, before defaults and validation are applied.
///
/// It holds only the high-signal fields the prompt asks about; everything else
/// a project needs is filled by `ProjectConfiguration`'s own defaults in
/// `resolved()`. Keeping it separate is what lets the prompt gather input
/// without knowing any compatibility rules (§15): it produces one of these, and
/// the validator — not the prompt — decides whether it can be generated.
///
/// The optional fields at the end are the `--advanced` questions (§4.2): `nil`
/// means "not asked", and `resolved()` hands a nil straight to the default it
/// would have taken anyway — so a default run and an advanced run that accepts
/// every suggestion produce the same configuration.
///
/// The line between the two groups is **what it costs to change the answer
/// after generation.** Every `--advanced` field can be changed afterwards by
/// editing one file in the generated project — a linter's config, the
/// organization name, the default branch. The fields above the line cannot:
/// platform, interface, architecture and dependency mode each decide what gets
/// written and how the project is driven, so getting one wrong means generating
/// again. That, and not "does it live in `scaffold.yml`" — they all do — is why
/// a question belongs above or below.
public struct PartialProjectConfiguration: Equatable, Sendable {
    public var platform: ApplePlatform
    public var name: String
    public var bundleIdentifier: String
    public var interface: UIFramework
    public var pattern: ArchitecturePattern
    public var includeExample: Bool?
    public var environments: [Environment]

    /// Never `nil`: the question is always asked, or always answered by
    /// `--dependency-manager`. It sits with the fields that always win over the
    /// preset base rather than with the `--advanced` ones, and the base it wins
    /// over is the one `PresetBases` resolved *for this mode* — so nothing
    /// downstream has to write the mode onto an already-normalized document.
    public var dependencyMode: DependencyMode

    public var organizationName: String?
    public var deploymentTarget: String?
    public var unitTestFramework: UnitTestFramework?
    public var swiftlint: Bool?
    public var swiftformat: Bool?
    public var gitDefaultBranch: String?

    public init(
        platform: ApplePlatform,
        name: String,
        bundleIdentifier: String,
        interface: UIFramework,
        pattern: ArchitecturePattern,
        includeExample: Bool?,
        environments: [Environment],
        // Defaulted so that a fixture describing a project with no dependencies
        // — which most are — says so by leaving it out. The prompt never relies
        // on this: it always has an answer to pass.
        dependencyMode: DependencyMode = ConfigurationDefaults.dependencyMode,
        organizationName: String? = nil,
        deploymentTarget: String? = nil,
        unitTestFramework: UnitTestFramework? = nil,
        swiftlint: Bool? = nil,
        swiftformat: Bool? = nil,
        gitDefaultBranch: String? = nil
    ) {
        self.platform = platform
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.interface = interface
        self.pattern = pattern
        self.includeExample = includeExample
        self.environments = environments
        self.dependencyMode = dependencyMode
        self.organizationName = organizationName
        self.deploymentTarget = deploymentTarget
        self.unitTestFramework = unitTestFramework
        self.swiftlint = swiftlint
        self.swiftformat = swiftformat
        self.gitDefaultBranch = gitDefaultBranch
    }

    /// The full configuration these answers describe, laid over a preset's.
    ///
    /// The base is the preset already resolved (`Preset.baseConfiguration`),
    /// not the preset itself, so this stays a pure value overlay: the
    /// interactive loop re-resolves on every edit and has nowhere to put a
    /// failure. Every field the prompt asked about wins, because an answer is
    /// a stated field; everything else is the preset's.
    ///
    /// Identity, platform and interface always come from the answers — a
    /// preset states none of them.
    ///
    /// The dependency mode is the one answer deliberately **not** written here.
    /// The base arrives from `PresetBases` already resolved for this mode, so
    /// it carries whatever normalization the mode triggers — Bundler pinned
    /// under `production`, and so on. Setting the field again would be a no-op
    /// at best; setting it on a base resolved for some *other* mode is the bug
    /// this arrangement exists to make impossible.
    public func resolved(over base: ProjectConfiguration?) -> ProjectConfiguration {
        guard var configuration = base else { return resolved() }

        configuration.project = .init(
            name: name,
            organizationName: organizationName ?? configuration.project.organizationName,
            bundleIdentifier: bundleIdentifier
        )
        configuration.product = .init(
            platform: platform,
            type: configuration.product.type,
            deploymentTarget: deploymentTarget
        )
        configuration.interface = .init(primary: interface)
        // `includeExample` qualifies a pattern and nothing else, so answering
        // the pattern answers it too: a preset's `true` cannot survive an
        // answer of `minimal`, which has no example to include. Carrying it
        // over made that combination `XS1201` — and the interactive loop, which
        // re-asks whatever it cannot resolve, then re-asked a question with no
        // acceptable answer.
        let inheritedExample = pattern == configuration.architecture.pattern
            ? configuration.architecture.includeExample
            : nil
        configuration.architecture = .init(
            pattern: pattern,
            includeExample: includeExample ?? inheritedExample
        )
        configuration.environments = environments

        if let unitTestFramework {
            configuration.testing.unit = unitTestFramework
        }
        if let swiftlint {
            configuration.quality.swiftlint = swiftlint
        }
        if let swiftformat {
            configuration.quality.swiftformat = swiftformat
        }
        if let gitDefaultBranch {
            configuration.git.defaultBranch = gitDefaultBranch
        }
        return configuration
    }

    /// The full configuration these answers describe, with defaults applied for
    /// every field the prompt did not ask about. The deployment target follows
    /// from the platform (Product's own default), so the prompt need not ask.
    ///
    /// This is the no-preset path, so the mode is written straight in: there is
    /// no preset document for it to have been normalized into, and the one
    /// overlay that normalization applies belongs to `production`.
    public func resolved() -> ProjectConfiguration {
        ProjectConfiguration(
            project: .init(name: name, organizationName: organizationName, bundleIdentifier: bundleIdentifier),
            product: .init(platform: platform, deploymentTarget: deploymentTarget),
            interface: .init(primary: interface),
            architecture: .init(pattern: pattern, includeExample: includeExample),
            dependencyManagement: .init(mode: dependencyMode),
            environments: environments,
            quality: .init(swiftlint: swiftlint, swiftformat: swiftformat),
            testing: .init(unit: unitTestFramework),
            git: .init(defaultBranch: gitDefaultBranch)
        )
    }
}

extension PartialProjectConfiguration {
    /// The three-environment set the prompt offers as an alternative to none —
    /// the same one documented in the plan's §4 and exercised end to end.
    public static let standardEnvironments: [Environment] = [
        Environment(
            name: "development",
            configuration: "Debug",
            bundleIdentifierSuffix: ".dev",
            displayNameSuffix: " Dev"
        ),
        Environment(
            name: "staging",
            configuration: "Staging",
            bundleIdentifierSuffix: ".stg",
            displayNameSuffix: " STG"
        ),
        Environment(name: "production", configuration: "Release")
    ]
}
