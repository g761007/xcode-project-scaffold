@testable import ScaffoldCore
import ScaffoldSchema
import Testing

private func configuration(
    platform: ApplePlatform,
    interface: UIFramework,
    pattern: ArchitecturePattern,
    includeExample: Bool?,
    deploymentTarget: String
) -> ProjectConfiguration {
    ProjectConfiguration(
        project: .init(name: "Bookshelf", bundleIdentifier: "com.example.bookshelf"),
        product: .init(platform: platform, deploymentTarget: deploymentTarget),
        interface: .init(primary: interface),
        architecture: .init(pattern: pattern, includeExample: includeExample)
    )
}

private func refusesExample(_ configuration: ProjectConfiguration) -> Bool {
    ConfigurationValidator().validate(configuration)
        .contains { $0.code == .swiftUIExampleRequiresObservation }
}

/// Issue #98: the SwiftUI architecture example is written with `@Observable`,
/// which needs iOS 17 / macOS 14, while the project floor is iOS 15 / macOS 11.
/// Before this rule such a project validated, generated, and then failed to
/// compile — the failure has to happen before anything is written.
///
/// Every case here was checked against a real `xcodebuild` at the stated
/// target before the rule was written, so the boundary sits on the version the
/// compiler actually enforces rather than on a guess.
@Suite("The SwiftUI example's deployment floor")
struct SwiftUIExampleAvailabilityTests {
    @Test("below the Observation floor the example is refused", arguments: [
        (ApplePlatform.iOS, "15.0"),
        (.iOS, "16.4"),
        (.macOS, "11.0"),
        (.macOS, "13.0")
    ])
    func refusedBelowFloor(platform: ApplePlatform, target: String) {
        #expect(refusesExample(configuration(
            platform: platform, interface: .swiftUI,
            pattern: .mvvm, includeExample: true, deploymentTarget: target
        )))
    }

    /// Exactly at the floor, not merely above it: a rule written as `<=` would
    /// refuse the very version the API shipped in.
    @Test("at the floor and above it is allowed", arguments: [
        (ApplePlatform.iOS, "17.0"),
        (.iOS, "18.0"),
        (.macOS, "14.0"),
        (.macOS, "15.0")
    ])
    func allowedAtAndAboveFloor(platform: ApplePlatform, target: String) {
        #expect(!refusesExample(configuration(
            platform: platform, interface: .swiftUI,
            pattern: .mvvm, includeExample: true, deploymentTarget: target
        )))
    }

    /// The fix the suggestion names has to actually work.
    @Test("switching the example off clears it")
    func exampleOffIsAllowed() {
        #expect(!refusesExample(configuration(
            platform: .iOS, interface: .swiftUI,
            pattern: .mvvm, includeExample: false, deploymentTarget: "15.0"
        )))
    }

    /// `minimal` has no example to be unavailable, at any target.
    @Test("minimal is unaffected")
    func minimalIsUnaffected() {
        #expect(!refusesExample(configuration(
            platform: .iOS, interface: .swiftUI,
            pattern: .minimal, includeExample: nil, deploymentTarget: "15.0"
        )))
    }

    /// The other interfaces observe through a closure rather than through
    /// Observation, and were confirmed to build at the floor. Refusing them
    /// would remove a combination that works.
    @Test("UIKit and AppKit examples are unaffected at the floor", arguments: [
        (ApplePlatform.iOS, UIFramework.uiKit, ArchitecturePattern.mvvm, "15.0"),
        (.iOS, .uiKit, .mvvmCoordinator, "15.0"),
        (.macOS, .appKit, .mvvm, "11.0")
    ])
    func otherInterfacesUnaffected(
        platform: ApplePlatform,
        interface: UIFramework,
        pattern: ArchitecturePattern,
        target: String
    ) {
        #expect(!refusesExample(configuration(
            platform: platform, interface: interface,
            pattern: pattern, includeExample: true, deploymentTarget: target
        )))
    }
}
