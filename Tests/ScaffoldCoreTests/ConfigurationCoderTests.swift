@testable import ScaffoldCore
import ScaffoldSchema
import Testing

@Suite("Decoding applies defaults")
struct ConfigurationDefaultsTests {
    let coder = ConfigurationCoder()

    /// The smallest document a user can write. Everything a project genuinely
    /// cannot guess — its name, its bundle identifier, and which UI framework
    /// it is built on — is required; everything else has a defensible default.
    static let minimalDocument = """
    project:
      name: MyApp
      bundleIdentifier: com.example.myapp
    interface:
      primary: uikit
    """

    @Test("every omitted field falls back to its default")
    func minimalDocumentFillsDefaults() throws {
        let configuration = try coder.decode(Self.minimalDocument)

        #expect(configuration.schemaVersion == 1)
        #expect(configuration.project.name == "MyApp")
        #expect(configuration.project.organizationName == "")
        #expect(configuration.project.bundleIdentifier == "com.example.myapp")
        #expect(configuration.product.platform == .iOS)
        #expect(configuration.product.type == .application)
        #expect(configuration.product.deploymentTarget == "18.0")
        #expect(configuration.language.primary == .swift)
        #expect(configuration.language.languageMode == .v6)
        #expect(configuration.interface.primary == .uiKit)
        #expect(configuration.architecture.pattern == .minimal)
        #expect(configuration.architecture.includeExample == nil)
        #expect(configuration.generator.type == .xcodegen)
        #expect(configuration.environments.isEmpty)
        #expect(configuration.quality.swiftlint)
        #expect(configuration.quality.swiftformat)
        #expect(configuration.testing.unit == .swiftTesting)
        #expect(configuration.git.defaultBranch == "main")
    }

    @Test("lifecycle follows from the interface when it is not stated")
    func lifecycleIsImpliedByInterface() throws {
        let uiKit = try coder.decode(Self.minimalDocument)
        #expect(uiKit.interface.lifecycle == .appDelegateSceneDelegate)

        let swiftUI = try coder.decode("""
        project:
          name: MyApp
          bundleIdentifier: com.example.myapp
        interface:
          primary: swiftui
        """)
        #expect(swiftUI.interface.lifecycle == .swiftUI)
    }

    /// Decoding must not silently repair a contradiction. Rejecting a UIKit
    /// project that asks for the SwiftUI lifecycle is the validation layer's
    /// job (XS1101/XS1102); the decoder's job is to report what was written.
    @Test("an explicitly stated lifecycle survives decoding even when it contradicts the interface")
    func explicitLifecycleIsPreserved() throws {
        let configuration = try coder.decode("""
        project:
          name: MyApp
          bundleIdentifier: com.example.myapp
        interface:
          primary: uikit
          lifecycle: swiftui
        """)

        #expect(configuration.interface.primary == .uiKit)
        #expect(configuration.interface.lifecycle == .swiftUI)
    }

    @Test("an environment without suffixes decodes with none, not with empty strings")
    func environmentSuffixesAreOptional() throws {
        let configuration = try coder.decode("""
        project:
          name: MyApp
          bundleIdentifier: com.example.myapp
        interface:
          primary: uikit
        environments:
          - name: production
            configuration: Release
        """)

        let environment = try #require(configuration.environments.first)
        #expect(environment.name == "production")
        #expect(environment.configuration == "Release")
        #expect(environment.bundleIdentifierSuffix == nil)
        #expect(environment.displayNameSuffix == nil)
    }
}

@Suite("Round-trip")
struct ConfigurationRoundTripTests {
    let coder = ConfigurationCoder()

    @Test("a fully populated configuration survives encode then decode unchanged")
    func fullyPopulatedConfigurationRoundTrips() throws {
        let original = ProjectConfiguration.fixture

        let decoded = try coder.decode(coder.encode(original))

        #expect(decoded == original)
    }

    /// A document that omits fields is not byte-identical after a round-trip —
    /// the defaults get written out. What must hold is that the *meaning* is
    /// stable: decoding the re-encoded document yields the same value.
    @Test("a minimal document reaches a fixed point after one round-trip")
    func minimalDocumentReachesFixedPoint() throws {
        let once = try coder.decode(ConfigurationDefaultsTests.minimalDocument)
        let twice = try coder.decode(coder.encode(once))

        #expect(twice == once)
    }

    @Test("encoding is deterministic")
    func encodingIsDeterministic() throws {
        let first = try coder.encode(ProjectConfiguration.fixture)
        let second = try coder.encode(ProjectConfiguration.fixture)

        #expect(first == second)
    }
}

@Suite("includeExample wire behaviour")
struct IncludeExampleTests {
    let coder = ConfigurationCoder()

    /// An unstated `includeExample` is a third state, not `false`: it is left
    /// out of the encoded document, and it resolves to an example only for a
    /// pattern that has one.
    @Test("an unstated includeExample is omitted on encode and resolves per pattern")
    func unstatedIncludeExample() throws {
        let minimal = try coder.decode(ConfigurationDefaultsTests.minimalDocument)
        #expect(minimal.architecture.includeExample == nil)
        #expect(minimal.architecture.generatesExample == false)
        #expect(try coder.encode(minimal).contains("includeExample") == false)

        let mvvm = try coder.decode("""
        project:
          name: MyApp
          bundleIdentifier: com.example.myapp
        interface:
          primary: uikit
        architecture:
          pattern: mvvm
        """)
        #expect(mvvm.architecture.includeExample == nil)
        #expect(mvvm.architecture.generatesExample)
    }

    @Test("a stated includeExample survives a round-trip", arguments: [true, false])
    func statedIncludeExampleRoundTrips(value: Bool) throws {
        let decoded = try coder.decode("""
        project:
          name: MyApp
          bundleIdentifier: com.example.myapp
        interface:
          primary: uikit
        architecture:
          pattern: mvvm
          includeExample: \(value)
        """)
        #expect(decoded.architecture.includeExample == value)

        let reDecoded = try coder.decode(coder.encode(decoded))
        #expect(reDecoded.architecture.includeExample == value)
    }
}

@Suite("Parsing failures")
struct ConfigurationParsingFailureTests {
    let coder = ConfigurationCoder()

    @Test("a missing required field names the field")
    func missingRequiredFieldNamesTheField() throws {
        let error = #expect(throws: ConfigurationParsingError.self) {
            try coder.decode("""
            project:
              name: MyApp
            interface:
              primary: uikit
            """)
        }

        #expect(error?.path == "project.bundleIdentifier")
        #expect(error?.message.contains("bundleIdentifier") == true)
    }

    @Test("an unrecognised enum value lists what is allowed")
    func unknownEnumValueListsAllowedValues() throws {
        let error = #expect(throws: ConfigurationParsingError.self) {
            try coder.decode("""
            project:
              name: MyApp
              bundleIdentifier: com.example.myapp
            interface:
              primary: flutter
            """)
        }

        #expect(error?.path == "interface.primary")
        #expect(error?.message.contains("flutter") == true)
        #expect(error?.message.contains("uikit") == true)
        #expect(error?.message.contains("swiftui") == true)
    }

    @Test("a value of the wrong type names the field rather than dumping a decoder trace")
    func typeMismatchNamesTheField() throws {
        let error = #expect(throws: ConfigurationParsingError.self) {
            try coder.decode("""
            project:
              name: MyApp
              bundleIdentifier: com.example.myapp
            interface:
              primary: uikit
            quality:
              swiftlint: sometimes
            """)
        }

        #expect(error?.path == "quality.swiftlint")
        #expect(error?.message == "Field 'quality.swiftlint' expects true or false.")
    }

    @Test("a failure inside a list names the element by index")
    func failureInsideListNamesTheIndex() throws {
        let error = #expect(throws: ConfigurationParsingError.self) {
            try coder.decode("""
            project:
              name: MyApp
              bundleIdentifier: com.example.myapp
            interface:
              primary: uikit
            environments:
              - name: development
                configuration: Debug
              - name: staging
            """)
        }

        #expect(error?.path == "environments[1].configuration")
    }

    @Test("malformed YAML is reported as malformed, not as a missing field")
    func malformedYAMLIsReportedAsSuch() throws {
        let error = #expect(throws: ConfigurationParsingError.self) {
            try coder.decode("project: [unclosed")
        }

        #expect(error?.path == nil)
    }

    @Test("an empty document is a parsing failure, not an empty configuration")
    func emptyDocumentFails() throws {
        #expect(throws: ConfigurationParsingError.self) {
            try coder.decode("")
        }
    }
}
