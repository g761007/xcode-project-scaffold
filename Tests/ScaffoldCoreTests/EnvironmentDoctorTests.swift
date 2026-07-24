@testable import ScaffoldCore
import ScaffoldSchema
import Testing

/// `doctor` exists to answer one question before a user finds out the hard way:
/// will `init` work here? So what matters is that a missing tool is reported as
/// missing, and that a missing *optional* tool is not treated as a blocker.
@Suite("Checking the machine")
struct EnvironmentDoctorTests {
    @Test("everything installed is everything found")
    func allPresent() {
        let checks = EnvironmentDoctor(processRunner: FakeProcessRunner()).check()

        // Hoisted out of `#expect`: the macro cannot type-check a `rethrows`
        // call taking a key path, and SwiftFormat rewrites the closure that
        // would work back into a key path.
        let everythingFound = checks.allSatisfy(\.found)
        #expect(everythingFound)
        #expect(checks.meetsRequirements)
    }

    @Test("the version is reported, because two Xcodes on one machine is normal")
    func reportsVersions() throws {
        let doctor = EnvironmentDoctor(
            processRunner: FakeProcessRunner(output: ["xcodegen": "Version: 2.44.1\n"])
        )

        let xcodegen = try #require(doctor.check().first { $0.name == "xcodegen" })
        #expect(xcodegen.detail == "Version: 2.44.1")
    }

    /// `xcodebuild -version` prints several lines; the first one names the
    /// release, and the rest is build metadata nobody reads in a checklist.
    @Test("only the first line of a multi-line version is kept")
    func firstLineOnly() throws {
        let doctor = EnvironmentDoctor(
            processRunner: FakeProcessRunner(output: ["xcodebuild": "Xcode 26.4.1\nBuild version 17F77\n"])
        )

        let xcodebuild = try #require(doctor.check().first { $0.name == "xcodebuild" })
        #expect(xcodebuild.detail == "Xcode 26.4.1")
    }

    @Test("a missing required tool fails the check and says what it was for")
    func missingRequirement() throws {
        let checks = EnvironmentDoctor(processRunner: FakeProcessRunner(missing: ["xcodegen"])).check()

        let xcodegen = try #require(checks.first { $0.name == "xcodegen" })
        #expect(!xcodegen.found)
        #expect(xcodegen.required)
        #expect(xcodegen.detail?.contains("brew install xcodegen") == true)
        #expect(!checks.meetsRequirements)
    }

    /// A project generates perfectly well without SwiftLint; it just cannot be
    /// linted. Reporting that as a failure would send people installing tools
    /// they were not asked for.
    @Test("a missing optional tool is reported without failing the check")
    func missingOptional() {
        let checks = EnvironmentDoctor(
            processRunner: FakeProcessRunner(missing: ["swiftlint", "swiftformat"])
        ).check()

        #expect(checks.contains { $0.name == "swiftlint" && !$0.found && !$0.required })
        #expect(checks.meetsRequirements)
    }

    /// Required means "a default `init` cannot proceed without it", and nothing
    /// else. §10.1 keeps xcodebuild out of a default run, so a machine with no
    /// Xcode command line tools can still generate a project — `doctor` must
    /// not claim otherwise.
    @Test("only what a default init needs is required")
    func requiredTools() {
        let checks = EnvironmentDoctor(processRunner: FakeProcessRunner()).check()
        let required = Set(checks.filter(\.required).map(\.name))

        #expect(required == ["git", "xcodegen"])
    }
}

/// Issue #63: how hard doctor insists on CocoaPods follows the configuration.
@Suite("CocoaPods in the doctor's list")
struct DoctorPodTests {
    private func makeConfiguration(mode: DependencyMode) -> ProjectConfiguration {
        ProjectConfiguration(
            project: .init(name: "App", bundleIdentifier: "com.example.app"),
            interface: .init(primary: .swiftUI),
            dependencyManagement: .init(mode: mode)
        )
    }

    @Test("pod is reported but optional with no configuration to consult")
    func optionalWithoutConfiguration() {
        let checks = EnvironmentDoctor(processRunner: FakeProcessRunner()).check()

        let pod = checks.first { $0.name == "pod" }
        #expect(pod != nil)
        #expect(pod?.required == false)
    }

    @Test("pod is required exactly when the mode reads pods", arguments: [
        (DependencyMode.disabled, false), (.spm, false), (.cocoapods, true), (.mixed, true)
    ])
    func requiredFollowsTheMode(mode: DependencyMode, required: Bool) {
        let checks = EnvironmentDoctor(processRunner: FakeProcessRunner())
            .check(for: makeConfiguration(mode: mode))

        #expect(checks.first { $0.name == "pod" }?.required == required)
    }

    @Test("a cocoapods configuration on a machine without pod fails requirements")
    func missingPodFailsWhenNeeded() {
        let checks = EnvironmentDoctor(processRunner: FakeProcessRunner(missing: ["pod"]))
            .check(for: makeConfiguration(mode: .cocoapods))

        #expect(!checks.meetsRequirements)
        #expect(checks.first { $0.name == "pod" }?.detail?.contains("brew install cocoapods") == true)
    }
}
