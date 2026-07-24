@testable import ScaffoldCore
import ScaffoldSchema
import Testing
import Yams

private func makeConfiguration(
    uiEnabled: Bool,
    launchPerformance: Bool = false
) -> ProjectConfiguration {
    ProjectConfiguration(
        project: .init(name: "Bookshelf", bundleIdentifier: "com.example.bookshelf"),
        interface: .init(primary: .swiftUI),
        testing: .init(unit: .swiftTesting, ui: .init(
            enabled: uiEnabled,
            launchPerformanceTest: launchPerformance
        ))
    )
}

private func planFiles(_ configuration: ProjectConfiguration) throws -> [String] {
    guard case let .valid(validated, _) = ConfigurationValidator().check(configuration) else {
        struct DidNotValidate: Error {}
        throw DidNotValidate()
    }
    return try GenerationPlanBuilder()
        .makePlan(for: validated, options: GenerationOptions(initializeGit: false, runGenerator: false))
        .files.map(\.path)
}

/// Issue #64: `testing.ui` — the wire format, the planned files, and the
/// target the project file grows. Off by default, apart from unit tests.
@Suite("UI tests in the configuration")
struct UITestsSchemaTests {
    @Test("the section decodes, and an omitted one means disabled")
    func decodes() throws {
        let coder = ConfigurationCoder()

        let stated = try coder.decode("""
        project:
          name: App
          bundleIdentifier: com.example.app
        interface:
          primary: swiftui
        testing:
          ui:
            enabled: true
            framework: xctest
            launchPerformanceTest: true
        """)
        #expect(stated.testing.ui == .init(enabled: true, framework: .xctest, launchPerformanceTest: true))
        #expect(stated.testing.unit == ConfigurationDefaults.unitTestFramework, "unit stays independent")

        let omitted = try coder.decode("""
        project:
          name: App
          bundleIdentifier: com.example.app
        interface:
          primary: swiftui
        """)
        #expect(omitted.testing.ui.enabled == false)
    }
}

@Suite("UI tests in the plan")
struct UITestsPlanTests {
    @Test("enabled plans the launch and smoke tests; the performance test needs asking")
    func enabledFiles() throws {
        let files = try planFiles(makeConfiguration(uiEnabled: true))

        #expect(files.contains("UITests/LaunchTests.swift"))
        #expect(files.contains("UITests/SmokeTests.swift"))
        #expect(!files.contains("UITests/LaunchPerformanceTests.swift"))
    }

    @Test("the performance test joins when asked for")
    func performanceFile() throws {
        let files = try planFiles(makeConfiguration(uiEnabled: true, launchPerformance: true))

        #expect(files.contains("UITests/LaunchPerformanceTests.swift"))
    }

    @Test("disabled plans no UITests directory at all")
    func disabledFiles() throws {
        let files = try planFiles(makeConfiguration(uiEnabled: false))

        #expect(!files.contains { $0.hasPrefix("UITests/") })
    }
}

@Suite("UI tests in project.yml")
struct UITestsSpecTests {
    private func parse(_ configuration: ProjectConfiguration) throws -> [String: Any] {
        let yaml = try XcodeGenSpecEncoder().encode(XcodeGenSpecBuilder().makeSpec(for: configuration))
        return try #require(Yams.load(yaml: yaml) as? [String: Any])
    }

    @Test("enabled grows a ui-testing target depending on the app")
    func target() throws {
        let document = try parse(makeConfiguration(uiEnabled: true))

        let targets = try #require(document["targets"] as? [String: Any])
        let uiTests = try #require(targets["BookshelfUITests"] as? [String: Any])
        #expect(uiTests["type"] as? String == "bundle.ui-testing")
        let dependencies = try #require(uiTests["dependencies"] as? [[String: Any]])
        #expect(dependencies.first?["target"] as? String == "Bookshelf")
    }

    @Test("the scheme's test action runs both test targets")
    func schemeTestTargets() throws {
        let document = try parse(makeConfiguration(uiEnabled: true))

        let schemes = try #require(document["schemes"] as? [String: Any])
        let scheme = try #require(schemes["Bookshelf"] as? [String: Any])
        let test = try #require(scheme["test"] as? [String: Any])
        #expect(test["targets"] as? [String] == ["BookshelfTests", "BookshelfUITests"])
    }

    @Test("disabled grows nothing")
    func absentWhenDisabled() throws {
        let document = try parse(makeConfiguration(uiEnabled: false))

        let targets = try #require(document["targets"] as? [String: Any])
        #expect(targets["BookshelfUITests"] == nil)
    }
}
