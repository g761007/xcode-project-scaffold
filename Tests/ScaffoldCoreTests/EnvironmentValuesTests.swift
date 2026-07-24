import Foundation
@testable import ScaffoldCore
import ScaffoldSchema
import Testing
import Yams

private func makeConfiguration(
    environments: [Environment] = [],
    secrets: Secrets? = nil
) -> ProjectConfiguration {
    ProjectConfiguration(
        project: .init(name: "Bookshelf", bundleIdentifier: "com.example.bookshelf"),
        interface: .init(primary: .swiftUI),
        environments: environments,
        secrets: secrets
    )
}

private let development = Environment(
    name: "development",
    configuration: "Debug",
    values: ["API_BASE_URL": "https://dev.example.com", "FEATURE_LOGGING": "true"]
)
private let production = Environment(name: "production", configuration: "Release")
private let apiKey = Secrets(keys: [.init(name: "API_KEY", example: "example-123")])

private func planFiles(_ configuration: ProjectConfiguration) throws -> [PlannedFile] {
    guard case let .valid(validated, _) = ConfigurationValidator().check(configuration) else {
        struct DidNotValidate: Error {}
        throw DidNotValidate()
    }
    return try GenerationPlanBuilder()
        .makePlan(for: validated, options: GenerationOptions(initializeGit: false, runGenerator: false))
        .files
}

/// Issue #65: values and secrets on the wire, in the plan, and in project.yml.
@Suite("Environment values and secrets")
struct EnvironmentValuesTests {
    @Test("values and secrets decode, and empty values stay off the wire")
    func wireFormat() throws {
        let coder = ConfigurationCoder()
        let decoded = try coder.decode("""
        project:
          name: App
          bundleIdentifier: com.example.app
        interface:
          primary: swiftui
        environments:
          - name: development
            configuration: Debug
            values:
              API_BASE_URL: https://dev.example.com
        secrets:
          keys:
            - name: API_KEY
              example: example-123
        """)

        #expect(decoded.environments.first?.values == ["API_BASE_URL": "https://dev.example.com"])
        #expect(decoded.secrets == Secrets(keys: [.init(name: "API_KEY", example: "example-123")]))

        // An environment with nothing to say writes no values key at all.
        let encoded = try coder.encode(makeConfiguration(environments: [production]))
        #expect(!encoded.contains("values:"))
        #expect(!encoded.contains("secrets:"))
    }

    @Test("each configuration with something to say gets its xcconfig")
    func xcconfigFiles() throws {
        let files = try planFiles(makeConfiguration(environments: [development, production], secrets: apiKey))
        let paths = files.map(\.path)

        #expect(paths.contains("Configurations/Debug.xcconfig"))
        // Secrets give every environment a file: production includes them too.
        #expect(paths.contains("Configurations/Release.xcconfig"))
        #expect(paths.contains("Configurations/Secrets.example.xcconfig"))
        #expect(paths.contains("Configurations/Secrets.xcconfig"))

        let debug = try #require(files.first { $0.path == "Configurations/Debug.xcconfig" }).contents
        #expect(debug.hasPrefix("#include \"Secrets.xcconfig\""))
        #expect(debug.contains("API_BASE_URL = https://dev.example.com"))
        #expect(debug.contains("FEATURE_LOGGING = true"))

        let secrets = try #require(files.first { $0.path == "Configurations/Secrets.xcconfig" }).contents
        #expect(secrets == "API_KEY = example-123\n")
    }

    @Test("the typed accessor covers every declared key")
    func appConfiguration() throws {
        let files = try planFiles(makeConfiguration(environments: [development], secrets: apiKey))

        let source = try #require(files.first { $0.path == "App/AppConfiguration.swift" }).contents
        #expect(source.contains("static let apiBaseURL: String = value(\"API_BASE_URL\")"))
        #expect(source.contains("static let apiKey: String = value(\"API_KEY\")"))
        #expect(source.contains("static let featureLogging: String = value(\"FEATURE_LOGGING\")"))
    }

    @Test("no values and no secrets plan none of it")
    func nothingDeclared() throws {
        let paths = try planFiles(makeConfiguration(environments: [production])).map(\.path)

        #expect(!paths.contains { $0.hasPrefix("Configurations/") })
        #expect(!paths.contains("App/AppConfiguration.swift"))
    }
}

@Suite("Environment values in project.yml")
struct EnvironmentValuesSpecTests {
    private func parse(_ configuration: ProjectConfiguration) throws -> [String: Any] {
        let yaml = try XcodeGenSpecEncoder().encode(XcodeGenSpecBuilder().makeSpec(for: configuration))
        return try #require(Yams.load(yaml: yaml) as? [String: Any])
    }

    @Test("configFiles point each configuration at its xcconfig")
    func configFiles() throws {
        let document = try parse(makeConfiguration(environments: [development, production], secrets: apiKey))

        let configFiles = try #require(document["configFiles"] as? [String: String])
        #expect(configFiles == [
            "Debug": "Configurations/Debug.xcconfig",
            "Release": "Configurations/Release.xcconfig"
        ])
    }

    @Test("secrets without environments attach to Debug and Release directly")
    func secretsOnly() throws {
        let document = try parse(makeConfiguration(secrets: apiKey))

        let configFiles = try #require(document["configFiles"] as? [String: String])
        #expect(configFiles == [
            "Debug": "Configurations/Secrets.xcconfig",
            "Release": "Configurations/Secrets.xcconfig"
        ])
    }

    @Test("every declared key reaches the Info.plist as a settings reference")
    func infoPlistKeys() throws {
        let document = try parse(makeConfiguration(environments: [development], secrets: apiKey))

        let targets = try #require(document["targets"] as? [String: Any])
        let app = try #require(targets["Bookshelf"] as? [String: Any])
        let info = try #require(app["info"] as? [String: Any])
        let properties = try #require(info["properties"] as? [String: Any])
        #expect(properties["API_BASE_URL"] as? String == "$(API_BASE_URL)")
        #expect(properties["API_KEY"] as? String == "$(API_KEY)")
        #expect(properties["FEATURE_LOGGING"] as? String == "$(FEATURE_LOGGING)")
    }

    @Test("nothing declared leaves project.yml as it was")
    func absentWithoutDeclarations() throws {
        let document = try parse(makeConfiguration(environments: [production]))

        #expect(document["configFiles"] == nil)
    }
}
