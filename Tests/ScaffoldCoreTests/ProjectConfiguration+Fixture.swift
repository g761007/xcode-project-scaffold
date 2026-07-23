import ScaffoldSchema

extension ProjectConfiguration {
    /// Every field set to a non-default value, so that a round-trip which
    /// silently drops a field cannot pass by accidentally matching a default.
    static let fixture = ProjectConfiguration(
        schemaVersion: 1,
        project: Project(
            name: "Fixture",
            organizationName: "Fixture Company",
            bundleIdentifier: "com.fixture.app"
        ),
        product: Product(
            platform: .macOS,
            type: .framework,
            deploymentTarget: "15.0"
        ),
        language: Language(
            primary: .swift,
            languageMode: .v5
        ),
        interface: Interface(
            primary: .appKit,
            lifecycle: .appDelegate
        ),
        architecture: Architecture(pattern: .clean),
        generator: Generator(type: .tuist),
        environments: [
            Environment(
                name: "development",
                configuration: "Debug",
                bundleIdentifierSuffix: ".dev",
                displayNameSuffix: " Dev"
            ),
            Environment(
                name: "production",
                configuration: "Release",
                bundleIdentifierSuffix: nil,
                displayNameSuffix: nil
            )
        ],
        quality: Quality(swiftlint: false, swiftformat: false),
        testing: Testing(unit: .xctest),
        git: Git(defaultBranch: "trunk")
    )
}
