import ScaffoldSchema

/// The answers `new` collects, before defaults and validation are applied.
///
/// It holds only the high-signal fields the prompt asks about; everything else
/// a project needs is filled by `ProjectConfiguration`'s own defaults in
/// `resolved()`. Keeping it separate is what lets the prompt gather input
/// without knowing any compatibility rules (§15): it produces one of these, and
/// the validator — not the prompt — decides whether it can be generated.
public struct PartialProjectConfiguration: Equatable, Sendable {
    public var platform: ApplePlatform
    public var name: String
    public var bundleIdentifier: String
    public var interface: UIFramework
    public var pattern: ArchitecturePattern
    public var includeExample: Bool?
    public var environments: [Environment]

    public init(
        platform: ApplePlatform,
        name: String,
        bundleIdentifier: String,
        interface: UIFramework,
        pattern: ArchitecturePattern,
        includeExample: Bool?,
        environments: [Environment]
    ) {
        self.platform = platform
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.interface = interface
        self.pattern = pattern
        self.includeExample = includeExample
        self.environments = environments
    }

    /// The full configuration these answers describe, with defaults applied for
    /// every field the prompt did not ask about. The deployment target follows
    /// from the platform (Product's own default), so the prompt need not ask.
    public func resolved() -> ProjectConfiguration {
        ProjectConfiguration(
            project: .init(name: name, bundleIdentifier: bundleIdentifier),
            product: .init(platform: platform),
            interface: .init(primary: interface),
            architecture: .init(pattern: pattern, includeExample: includeExample),
            environments: environments
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
