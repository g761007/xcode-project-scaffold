@testable import ScaffoldCore
import ScaffoldSchema
import Testing

@Suite("Field validity")
struct FieldValidityTests {
    @Test("a bundle identifier must be reverse-DNS", arguments: [
        "myapp", "", "com..myapp", "com.example.my app", "com.example.my_app",
        "-com.example.myapp", "com.example.myapp-"
    ])
    func invalidBundleIdentifier(identifier: String) {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.project.bundleIdentifier = identifier
        }

        #expect(codes(configuration).contains(.invalidBundleIdentifier))
    }

    @Test("these bundle identifiers are accepted", arguments: [
        "com.example.myapp", "com.example", "com.example.my-app", "com.Example.MyApp2"
    ])
    func validBundleIdentifier(identifier: String) {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.project.bundleIdentifier = identifier
        }

        #expect(!codes(configuration).contains(.invalidBundleIdentifier))
    }

    @Test("a deployment target must be a version number", arguments: [
        "eighteen", "", "18.", ".0", "18.x", "18.0.0.1", "-1"
    ])
    func malformedDeploymentTarget(target: String) {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.product.deploymentTarget = target
        }

        #expect(codes(configuration).contains(.malformedDeploymentTarget))
    }

    @Test("these deployment targets parse", arguments: ["15", "18.0", "26.1.2"])
    func wellFormedDeploymentTarget(target: String) {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.product.deploymentTarget = target
        }

        #expect(!codes(configuration).contains(.malformedDeploymentTarget))
    }

    /// A malformed target cannot also be "too low" — reporting both would send
    /// the user chasing a second problem that does not exist.
    @Test("a malformed deployment target is not also reported as too low")
    func malformedTargetIsNotAlsoTooLow() {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.product.deploymentTarget = "eighteen"
        }

        #expect(!codes(configuration).contains(.deploymentTargetNotSupported))
    }

    @Test("a deployment target below the supported floor is rejected", arguments: ["12.0", "14.9"])
    func deploymentTargetNotSupported(target: String) {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.product.deploymentTarget = target
        }

        #expect(codes(configuration).contains(.deploymentTargetNotSupported))
    }

    @Test("the floor itself and anything above it is accepted", arguments: ["15.0", "18.0", "26.0"])
    func deploymentTargetAtOrAboveFloor(target: String) {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.product.deploymentTarget = target
        }

        #expect(!codes(configuration).contains(.deploymentTargetNotSupported))
    }

    /// macOS and iOS have different floors, so the rule must read the platform
    /// rather than applying one number to everything.
    @Test("the floor depends on the platform")
    func floorIsPerPlatform() {
        let macOS = ProjectConfiguration.validBaseline.with {
            $0.product.platform = .macOS
            $0.interface = .init(primary: .appKit)
            $0.product.deploymentTarget = "11.0"
        }
        #expect(!codes(macOS).contains(.deploymentTargetNotSupported))

        let iOS = ProjectConfiguration.validBaseline.with { $0.product.deploymentTarget = "11.0" }
        #expect(codes(iOS).contains(.deploymentTargetNotSupported))
    }

    @Test("a project name must be usable as a target name", arguments: [
        "", "   ", "My/App", "My:App", "My\\App", "My\nApp",
        ".", "..", " MyApp", "MyApp ", "My\u{0}App"
    ])
    func invalidProjectName(name: String) {
        let configuration = ProjectConfiguration.validBaseline.with { $0.project.name = name }

        #expect(codes(configuration).contains(.invalidProjectName))
    }

    @Test("these project names are accepted", arguments: ["MyApp", "My App", "my-app_2"])
    func validProjectName(name: String) {
        let configuration = ProjectConfiguration.validBaseline.with { $0.project.name = name }

        #expect(!codes(configuration).contains(.invalidProjectName))
    }
}

@Suite("Environments")
struct EnvironmentValidationTests {
    @Test("duplicate environment names are rejected, distinct ones are not")
    func duplicateNames() {
        let rejected = ProjectConfiguration.validBaseline.with {
            $0.environments = [
                Environment(name: "staging", configuration: "Debug"),
                Environment(name: "staging", configuration: "Release")
            ]
        }
        #expect(codes(rejected).contains(.duplicateEnvironmentName))

        let allowed = ProjectConfiguration.validBaseline.with {
            $0.environments = [
                Environment(name: "development", configuration: "Debug"),
                Environment(name: "staging", configuration: "Release")
            ]
        }
        #expect(!codes(allowed).contains(.duplicateEnvironmentName))
    }

    @Test("duplicate build configuration names are rejected, distinct ones are not")
    func duplicateConfigurations() {
        let rejected = ProjectConfiguration.validBaseline.with {
            $0.environments = [
                Environment(name: "development", configuration: "Debug"),
                Environment(name: "staging", configuration: "Debug")
            ]
        }
        #expect(codes(rejected).contains(.duplicateBuildConfiguration))

        let allowed = ProjectConfiguration.validBaseline.with {
            $0.environments = [
                Environment(name: "development", configuration: "Debug"),
                Environment(name: "staging", configuration: "Release")
            ]
        }
        #expect(!codes(allowed).contains(.duplicateBuildConfiguration))
    }

    /// One issue per repeat, not one per rule: a user with four clashing
    /// environments should see all four, not fix one and rerun.
    @Test("every repeat is reported, not just the first")
    func everyRepeatIsReported() {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.environments = [
                Environment(name: "staging", configuration: "A"),
                Environment(name: "staging", configuration: "B"),
                Environment(name: "staging", configuration: "C")
            ]
        }

        let reported = codes(configuration).filter { $0 == .duplicateEnvironmentName }
        #expect(reported.count == 2)
    }

    @Test("an environment suffix that breaks the bundle identifier is rejected")
    func invalidBundleIdentifierSuffix() {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.environments = [Environment(
                name: "development",
                configuration: "Debug",
                bundleIdentifierSuffix: " dev"
            )]
        }

        let issues = ConfigurationValidator().validate(configuration)
        #expect(issues.map(\.code).contains(.invalidBundleIdentifier))
        #expect(issues.first?.path == "environments[0].bundleIdentifierSuffix")
    }

    /// A typo in the base identifier must not produce one issue per
    /// environment — the reader would think they had five problems.
    @Test("a broken base identifier is reported once, not once per environment")
    func brokenBaseIdentifierReportedOnce() {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.project.bundleIdentifier = "nope"
            $0.environments = [
                Environment(name: "a", configuration: "A", bundleIdentifierSuffix: ".a"),
                Environment(name: "b", configuration: "B", bundleIdentifierSuffix: ".b")
            ]
        }

        let reported = codes(configuration).filter { $0 == .invalidBundleIdentifier }
        #expect(reported.count == 1)
    }

    /// Environment names are user-facing labels and build configurations are
    /// Xcode identifiers; comparing them case-insensitively would reject
    /// `Debug`/`debug` pairs that Xcode itself treats as distinct.
    @Test("names differing only by case are distinct")
    func caseSensitiveComparison() {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.environments = [
                Environment(name: "staging", configuration: "Debug"),
                Environment(name: "Staging", configuration: "debug")
            ]
        }

        #expect(codes(configuration).isEmpty)
    }
}
