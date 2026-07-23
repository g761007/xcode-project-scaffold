@testable import ScaffoldCore
import ScaffoldSchema
import Testing
import Yams

/// `project.yml` is what the user opens, edits and diffs for the rest of the
/// project's life, so its exact text is pinned — key order keeps diffs stable
/// and quoting keeps `18.10` from being read as `18.1`. Neither is visible to a
/// structural comparison, which is why this file is the plan's single exception
/// to "no text pinning" (§12.1). `EmittedStructureTests` below covers meaning.
@Suite("Encoding project.yml")
struct XcodeGenSpecEncoderTests {
    let encoder = XcodeGenSpecEncoder()
    let builder = XcodeGenSpecBuilder()

    func encode(_ configuration: ProjectConfiguration) throws -> String {
        try encoder.encode(builder.makeSpec(for: configuration))
    }

    static let goldenWithoutEnvironments = """
    name: MyApp
    options:
      deploymentTarget:
        iOS: '18.0'
    settings:
      base:
        SWIFT_VERSION: '6'
        SWIFT_STRICT_CONCURRENCY: complete
    targets:
      MyApp:
        type: application
        platform: iOS
        sources:
        - App
        - Resources
        settings:
          base:
            PRODUCT_BUNDLE_IDENTIFIER: com.example.myapp
            PRODUCT_DISPLAY_NAME: MyApp
        info:
          path: App/Info.plist
          properties:
            CFBundleDisplayName: $(PRODUCT_DISPLAY_NAME)
            UILaunchScreen: {}
            UIApplicationSceneManifest:
              UIApplicationSupportsMultipleScenes: false
      MyAppTests:
        type: bundle.unit-test
        platform: iOS
        sources:
        - Tests
        settings:
          base:
            GENERATE_INFOPLIST_FILE: true
        dependencies:
        - target: MyApp
    schemes:
      MyApp:
        build:
          targets:
            MyApp: all
        run:
          config: Debug
        test:
          config: Debug
          targets:
          - MyAppTests
        archive:
          config: Release

    """

    static let goldenWithEnvironments = """
    name: MyApp
    options:
      deploymentTarget:
        iOS: '18.0'
    configs:
      Debug: debug
      Release: release
    settings:
      base:
        SWIFT_VERSION: '6'
        SWIFT_STRICT_CONCURRENCY: complete
    targets:
      MyApp:
        type: application
        platform: iOS
        sources:
        - App
        - Resources
        settings:
          base:
            PRODUCT_BUNDLE_IDENTIFIER: com.example.myapp
            PRODUCT_DISPLAY_NAME: MyApp
          configs:
            Debug:
              PRODUCT_BUNDLE_IDENTIFIER: com.example.myapp.dev
              PRODUCT_DISPLAY_NAME: MyApp Dev
        info:
          path: App/Info.plist
          properties:
            CFBundleDisplayName: $(PRODUCT_DISPLAY_NAME)
            UILaunchScreen: {}
            UIApplicationSceneManifest:
              UIApplicationSupportsMultipleScenes: false
      MyAppTests:
        type: bundle.unit-test
        platform: iOS
        sources:
        - Tests
        settings:
          base:
            GENERATE_INFOPLIST_FILE: true
        dependencies:
        - target: MyApp
    schemes:
      MyApp-Development:
        build:
          targets:
            MyApp: all
        run:
          config: Debug
        test:
          config: Debug
          targets:
          - MyAppTests
        archive:
          config: Debug
      MyApp:
        build:
          targets:
            MyApp: all
        run:
          config: Release
        test:
          config: Release
          targets:
          - MyAppTests
        archive:
          config: Release

    """

    @Test("a project with no environments")
    func withoutEnvironments() throws {
        #expect(try encode(.validBaseline) == Self.goldenWithoutEnvironments)
    }

    /// The only difference the reader should have to hold in their head is the
    /// `configs` block, the per-configuration overrides and the second scheme.
    @Test("the same project with two environments")
    func withEnvironments() throws {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.environments = [
                Environment(
                    name: "development",
                    configuration: "Debug",
                    bundleIdentifierSuffix: ".dev",
                    displayNameSuffix: " Dev"
                ),
                Environment(name: "production", configuration: "Release")
            ]
        }

        #expect(try encode(configuration) == Self.goldenWithEnvironments)
    }

    @Test("a SwiftUI project has no scene manifest")
    func swiftUIHasNoSceneManifest() throws {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.interface = .init(primary: .swiftUI)
        }

        #expect(try !(encode(configuration).contains("UIApplicationSceneManifest")))
    }

    @Test("switching unit tests off removes the target and the scheme's test action")
    func withoutTests() throws {
        let yaml = try encode(.validBaseline.with { $0.testing.unit = .disabled })

        #expect(!yaml.contains("MyAppTests"))
        #expect(!yaml.contains("bundle.unit-test"))
        #expect(!yaml.contains("test:"))
    }

    @Test("encoding is deterministic")
    func deterministic() throws {
        #expect(try encode(.validBaseline) == encode(.validBaseline))
    }
}

/// The golden strings above fail loudly on any change, including a cosmetic
/// one. These read the document back and assert what it *means*, so a failure
/// here says the project would come out different — not merely that the text
/// moved.
@Suite("The emitted document parses to the right structure")
struct EmittedStructureTests {
    func parse(_ configuration: ProjectConfiguration) throws -> [String: Any] {
        let yaml = try XcodeGenSpecEncoder().encode(XcodeGenSpecBuilder().makeSpec(for: configuration))
        return try #require(try Yams.load(yaml: yaml) as? [String: Any])
    }

    @Test("the app and test targets are declared with the right types")
    func targets() throws {
        let targets = try #require(parse(.validBaseline)["targets"] as? [String: Any])

        #expect(Set(targets.keys) == ["MyApp", "MyAppTests"])
        #expect((targets["MyApp"] as? [String: Any])?["type"] as? String == "application")
        #expect((targets["MyAppTests"] as? [String: Any])?["type"] as? String == "bundle.unit-test")
    }

    /// The pitfall this project verified by hand: XcodeGen gives test bundles
    /// no Info.plist, and the build then fails at code signing.
    @Test("the test bundle is told to generate its own Info.plist")
    func bundleGeneratesItsOwnInfoPlist() throws {
        let targets = try #require(parse(.validBaseline)["targets"] as? [String: Any])
        let tests = try #require(targets["MyAppTests"] as? [String: Any])
        let settings = try #require(tests["settings"] as? [String: Any])
        let base = try #require(settings["base"] as? [String: Any])

        #expect(base["GENERATE_INFOPLIST_FILE"] as? Bool == true)
    }

    @Test("each environment yields a configuration and a scheme")
    func environments() throws {
        let parsed = try parse(.validBaseline.with {
            $0.environments = [
                Environment(name: "development", configuration: "Debug", bundleIdentifierSuffix: ".dev"),
                Environment(name: "production", configuration: "Release")
            ]
        })

        let configs = try #require(parsed["configs"] as? [String: Any])
        #expect(configs["Debug"] as? String == "debug")
        #expect(configs["Release"] as? String == "release")

        let schemes = try #require(parsed["schemes"] as? [String: Any])
        #expect(Set(schemes.keys) == ["MyApp-Development", "MyApp"])
    }

    @Test("a suffixed environment overrides the bundle identifier for its configuration")
    func perConfigurationOverride() throws {
        let parsed = try parse(.validBaseline.with {
            $0.environments = [
                Environment(name: "development", configuration: "Debug", bundleIdentifierSuffix: ".dev")
            ]
        })

        let targets = try #require(parsed["targets"] as? [String: Any])
        let app = try #require(targets["MyApp"] as? [String: Any])
        let settings = try #require(app["settings"] as? [String: Any])
        let overrides = try #require(settings["configs"] as? [String: Any])
        let debug = try #require(overrides["Debug"] as? [String: Any])

        #expect(debug["PRODUCT_BUNDLE_IDENTIFIER"] as? String == "com.example.myapp.dev")
    }

    @Test("no environments means no explicit configs block")
    func noConfigsBlock() throws {
        #expect(try parse(.validBaseline)["configs"] == nil)
    }
}

/// Version-like values must survive the round trip through YAML. Unquoted,
/// `18.10` parses as the float 18.1 — a different iOS release — and nothing
/// downstream would notice.
@Suite("Version values survive YAML")
struct DeploymentTargetQuotingTests {
    @Test("a deployment target reads back as the text it was written with", arguments: [
        "18.0", "18.10", "26", "15.0"
    ])
    func deploymentTargetSurvives(written: String) throws {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.product.deploymentTarget = written
        }
        let yaml = try XcodeGenSpecEncoder().encode(XcodeGenSpecBuilder().makeSpec(for: configuration))

        let parsed = try #require(try Yams.load(yaml: yaml) as? [String: Any])
        let options = try #require(parsed["options"] as? [String: Any])
        let targets = try #require(options["deploymentTarget"] as? [String: Any])

        #expect(targets["iOS"] as? String == written)
    }

    @Test("the language mode reads back as a string, not a number")
    func languageModeSurvives() throws {
        let yaml = try XcodeGenSpecEncoder().encode(XcodeGenSpecBuilder().makeSpec(for: .validBaseline))

        let parsed = try #require(try Yams.load(yaml: yaml) as? [String: Any])
        let settings = try #require(parsed["settings"] as? [String: Any])
        let base = try #require(settings["base"] as? [String: Any])

        #expect(base["SWIFT_VERSION"] as? String == "6")
    }
}
