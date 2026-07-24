@testable import ScaffoldCore
import ScaffoldSchema
import Testing

/// The round-trip tests compare *models*, so they pass unchanged even if every
/// YAML key were renamed — encoder and decoder rename in lockstep. These tests
/// pin the wire format itself: the key names, their order, and the quoting.
@Suite("scaffold.yml wire contract")
struct YAMLContractTests {
    let coder = ConfigurationCoder()

    /// Byte-for-byte. Every key here appears in users' files; renaming one is a
    /// breaking change.
    static let goldenDocument = """
    schemaVersion: 1
    project:
      name: MyApp
      organizationName: My Company
      bundleIdentifier: com.example.myapp
    product:
      platform: ios
      type: application
      deploymentTarget: '18.0'
    language:
      primary: swift
      languageMode: '6'
    interface:
      primary: uikit
      lifecycle: app-delegate-scene-delegate
    architecture:
      pattern: minimal
    generator:
      type: xcodegen
    dependencyManagement:
      mode: none
    environments: []
    quality:
      swiftlint: true
      swiftformat: true
    testing:
      unit: swift-testing
    git:
      defaultBranch: main

    """

    static let canonicalConfiguration = ProjectConfiguration(
        project: .init(
            name: "MyApp",
            organizationName: "My Company",
            bundleIdentifier: "com.example.myapp"
        ),
        interface: .init(primary: .uiKit)
    )

    @Test("encoding emits exactly the documented keys, in the documented order")
    func encodingMatchesTheWireFormat() throws {
        let encoded = try coder.encode(Self.canonicalConfiguration)

        #expect(encoded == Self.goldenDocument)
    }

    /// The example in `docs/plans/xcode-project-scaffold-plan.md` §4, verbatim.
    /// If the schema drifts from the documentation, this fails.
    @Test("the example documented in the plan decodes as written")
    func documentedExampleDecodes() throws {
        let decoded = try coder.decode("""
        schemaVersion: 1

        project:
          name: MyApp
          organizationName: My Company
          bundleIdentifier: com.example.myapp

        product:
          platform: ios
          type: application
          deploymentTarget: "18.0"

        language:
          primary: swift
          languageMode: "6"

        interface:
          primary: uikit
          lifecycle: app-delegate-scene-delegate

        architecture:
          pattern: minimal

        generator:
          type: xcodegen

        environments: []

        quality:
          swiftlint: true
          swiftformat: true

        testing:
          unit: swift-testing

        git:
          defaultBranch: main
        """)

        #expect(decoded == Self.canonicalConfiguration)
    }

    @Test("the documented three-environment block decodes as written")
    func documentedEnvironmentsDecode() throws {
        let decoded = try coder.decode("""
        project:
          name: MyApp
          bundleIdentifier: com.example.myapp
        interface:
          primary: uikit
        environments:
          - name: development
            configuration: Debug
            bundleIdentifierSuffix: .dev
            displayNameSuffix: " Dev"
          - name: staging
            configuration: Staging
            bundleIdentifierSuffix: .stg
            displayNameSuffix: " STG"
          - name: production
            configuration: Release
        """)

        #expect(decoded.environments == [
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
        ])
    }

    /// A deployment target written without quotes is a YAML float, and a
    /// language mode without quotes is an integer. The hazard is not rejection
    /// — it is a float round-trip quietly turning `18.10` into `18.1`, which
    /// names a different iOS release. This pins that the source text survives,
    /// so users who forget the quotes still get the version they wrote.
    @Test(
        "an unquoted version-like value keeps its exact text",
        arguments: [
            ("18.0", "18.0"),
            ("18.10", "18.10"),
            ("26", "26")
        ]
    )
    func unquotedVersionKeepsItsText(written: String, expected: String) throws {
        let decoded = try coder.decode("""
        project:
          name: MyApp
          bundleIdentifier: com.example.myapp
        interface:
          primary: uikit
        product:
          deploymentTarget: \(written)
        """)

        #expect(decoded.product.deploymentTarget == expected)
    }

    /// The encoder must quote them on the way out regardless, so a generated
    /// `scaffold.yml` never depends on that leniency.
    @Test("encoding always quotes version-like values")
    func encodingQuotesVersionLikeValues() throws {
        let encoded = try coder.encode(Self.canonicalConfiguration)

        #expect(encoded.contains("deploymentTarget: '18.0'"))
        #expect(encoded.contains("languageMode: '6'"))
    }
}
