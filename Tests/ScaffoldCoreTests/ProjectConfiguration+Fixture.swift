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
        dependencyManagement: DependencyManagement(
            mode: .mixed,
            spm: .init(packages: [
                SwiftPackage(
                    name: "FixturePackage",
                    url: "https://example.com/fixture.git",
                    requirement: .exact("9.9.9"),
                    products: [PackageProduct(name: "FixtureProduct", targets: ["Fixture"])]
                )
            ]),
            cocoapods: .init(
                pods: [Pod(
                    name: "FixturePod",
                    source: .gitTag(url: "https://example.com/pod.git", tag: "v9"),
                    subspecs: ["Core"]
                )],
                bundler: .init(enabled: true)
            )
        ),
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
        testing: Testing(unit: .xctest, ui: UITesting(
            enabled: true,
            framework: .xctest,
            launchPerformanceTest: true
        )),
        git: Git(defaultBranch: "trunk")
    )
}
