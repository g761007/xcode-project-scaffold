@testable import ScaffoldCore
import ScaffoldSchema
import Testing

private let builder = XcodeGenSpecBuilder()

@Suite("Building a spec without environments")
struct SpecWithoutEnvironmentsTests {
    @Test("the project takes its name, platform and deployment target from the configuration")
    func projectLevel() {
        let spec = builder.makeSpec(for: .validBaseline)

        #expect(spec.name == "MyApp")
        #expect(spec.platform == "iOS")
        #expect(spec.deploymentTarget == "18.0")
        #expect(spec.languageMode == "6")
    }

    /// Swift 5 has no strict concurrency to switch on, so the setting is only
    /// written for language mode 6.
    @Test("strict concurrency follows the language mode")
    func strictConcurrency() {
        #expect(builder.makeSpec(for: .validBaseline).strictConcurrency)

        let swift5 = ProjectConfiguration.validBaseline.with { $0.language.languageMode = .v5 }
        #expect(!builder.makeSpec(for: swift5).strictConcurrency)
    }

    /// An empty `configurations` list means "leave XcodeGen's Debug and
    /// Release alone" — writing them out explicitly would be noise.
    @Test("no environments means no explicit configurations")
    func noConfigurations() {
        #expect(builder.makeSpec(for: .validBaseline).configurations.isEmpty)
    }

    @Test("the app target carries the bundle identifier and no per-configuration overrides")
    func appTarget() {
        let target = builder.makeSpec(for: .validBaseline).appTarget

        #expect(target.productType == "application")
        #expect(target.bundleIdentifier == "com.example.myapp")
        #expect(target.displayName == "MyApp")
        #expect(target.sources == ["App", "Resources"])
        #expect(target.overrides.isEmpty)
    }

    @Test("one scheme, named after the project")
    func singleScheme() {
        let schemes = builder.makeSpec(for: .validBaseline).schemes

        #expect(schemes.count == 1)
        #expect(schemes.first?.name == "MyApp")
        #expect(schemes.first?.runConfiguration == "Debug")
        #expect(schemes.first?.archiveConfiguration == "Release")
    }
}

@Suite("Building a spec with environments")
struct SpecWithEnvironmentsTests {
    static let configuration = ProjectConfiguration.validBaseline.with {
        $0.environments = [
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

    /// XcodeGen needs each configuration typed. The schema does not carry that,
    /// so it is inferred: `Debug` is the debug build, everything else is
    /// optimised. A project needing anything else edits project.yml, which
    /// describes it from then on (ADR-0001).
    @Test("each environment becomes a configuration, typed by convention")
    func configurations() {
        let configurations = builder.makeSpec(for: Self.configuration).configurations

        #expect(configurations == [
            XcodeGenSpec.Configuration(name: "Debug", optimized: false),
            XcodeGenSpec.Configuration(name: "Staging", optimized: true),
            XcodeGenSpec.Configuration(name: "Release", optimized: true)
        ])
    }

    /// A project where every configuration is optimised cannot be debugged at
    /// all, which is worse than picking one. The first environment is the least
    /// surprising choice: the list runs from development outwards.
    @Test("with no configuration named Debug, the first environment becomes the debug build")
    func debugFallback() {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.environments = [
                Environment(name: "dev", configuration: "Dev"),
                Environment(name: "staging", configuration: "Staging"),
                Environment(name: "production", configuration: "Release")
            ]
        }

        #expect(builder.makeSpec(for: configuration).configurations == [
            XcodeGenSpec.Configuration(name: "Dev", optimized: false),
            XcodeGenSpec.Configuration(name: "Staging", optimized: true),
            XcodeGenSpec.Configuration(name: "Release", optimized: true)
        ])
    }

    @Test("suffixes are applied per configuration")
    func overrides() {
        let overrides = builder.makeSpec(for: Self.configuration).appTarget.overrides

        #expect(overrides == [
            XcodeGenSpec.TargetOverride(
                configuration: "Debug",
                bundleIdentifier: "com.example.myapp.dev",
                displayName: "MyApp Dev"
            ),
            XcodeGenSpec.TargetOverride(
                configuration: "Staging",
                bundleIdentifier: "com.example.myapp.stg",
                displayName: "MyApp STG"
            )
        ])
    }

    /// The environment with no suffixes produces the same values as the base,
    /// so writing an override for it would be redundant.
    @Test("an environment without suffixes gets no override")
    func noRedundantOverride() {
        let overrides = builder.makeSpec(for: Self.configuration).appTarget.overrides

        #expect(!overrides.contains { $0.configuration == "Release" })
    }

    /// The Release environment keeps the bare project name because that is the
    /// scheme used to archive for the App Store and the one Xcode selects on
    /// opening. Every other environment is suffixed.
    @Test("schemes are named after their environment, except the Release one")
    func schemeNames() {
        let schemes = builder.makeSpec(for: Self.configuration).schemes

        #expect(schemes.map(\.name) == ["MyApp-Development", "MyApp-Staging", "MyApp"])
    }

    @Test("each scheme runs and archives its own configuration")
    func schemeConfigurations() {
        let schemes = builder.makeSpec(for: Self.configuration).schemes

        #expect(schemes.map(\.runConfiguration) == ["Debug", "Staging", "Release"])
        #expect(schemes.map(\.archiveConfiguration) == ["Debug", "Staging", "Release"])
    }

    @Test("with no Release environment every scheme is suffixed")
    func noReleaseEnvironment() {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.environments = [
                Environment(name: "alpha", configuration: "Alpha"),
                Environment(name: "beta", configuration: "Beta")
            ]
        }

        #expect(builder.makeSpec(for: configuration).schemes.map(\.name) == ["MyApp-Alpha", "MyApp-Beta"])
    }

    /// `String.capitalized` would turn `iOSBeta` into `Iosbeta`.
    @Test("only the first letter of an environment name is changed")
    func capitalisationLeavesTheRestAlone() {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.environments = [Environment(name: "iOSBeta", configuration: "Beta")]
        }

        #expect(builder.makeSpec(for: configuration).schemes.first?.name == "MyApp-IOSBeta")
    }
}

@Suite("Platform and interface shape the Info.plist")
struct SpecInfoPlistTests {
    /// UIKit apps are scene-based from iOS 13 onwards, and Xcode 26's own
    /// template still generates a SceneDelegate. SwiftUI apps have none.
    @Test("only UIKit gets a scene manifest")
    func sceneManifest() {
        #expect(builder.makeSpec(for: .validBaseline).appTarget.infoPlist.includesSceneManifest)

        let swiftUI = ProjectConfiguration.validBaseline.with { $0.interface = .init(primary: .swiftUI) }
        #expect(!builder.makeSpec(for: swiftUI).appTarget.infoPlist.includesSceneManifest)
    }

    /// `UILaunchScreen` and the scene manifest are iOS keys. macOS is rejected
    /// by validation today, but the spec still has to describe it coherently
    /// rather than emit iOS keys for a Mac app.
    @Test("macOS gets neither launch screen nor scene manifest")
    func macOSHasNoIOSKeys() {
        let macOS = ProjectConfiguration.validBaseline.with {
            $0.product.platform = .macOS
            $0.interface = .init(primary: .appKit)
        }
        let infoPlist = builder.makeSpec(for: macOS).appTarget.infoPlist

        #expect(!infoPlist.includesLaunchScreen)
        #expect(!infoPlist.includesSceneManifest)
    }

    @Test("iOS gets a launch screen dictionary rather than a storyboard")
    func iOSLaunchScreen() {
        #expect(builder.makeSpec(for: .validBaseline).appTarget.infoPlist.includesLaunchScreen)
    }
}

@Suite("The test target")
struct SpecTestTargetTests {
    @Test("a test target is produced, named after the project")
    func targetExists() throws {
        let target = try #require(builder.makeSpec(for: .validBaseline).testTarget)

        #expect(target.name == "MyAppTests")
        #expect(target.sources == ["Tests"])
    }

    @Test("no test target when unit testing is switched off")
    func noTestTarget() {
        let configuration = ProjectConfiguration.validBaseline.with { $0.testing.unit = .disabled }

        #expect(builder.makeSpec(for: configuration).testTarget == nil)
    }
}
