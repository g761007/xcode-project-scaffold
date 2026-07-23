@testable import ScaffoldCore
import ScaffoldSchema
import Testing

/// One configuration per code, with the exact text it must produce.
///
/// A code with no entry here is unreachable — which is exactly how XS0002 and
/// XS1201 survived in the spec until someone noticed by hand. The message text
/// is pinned because without it `XS1101` once emitted `requires swiftui`
/// instead of the documented `requires SwiftUI`, and nothing failed.
struct ValidationTrigger: Sendable, CustomStringConvertible {
    let code: ValidationCode
    let message: String
    let configuration: ProjectConfiguration

    var description: String {
        code.rawValue
    }
}

@Suite("Rules obey the two-group contract")
struct ValidationContractTests {
    static let triggers: [ValidationTrigger] = [
        ValidationTrigger(
            code: .platformNotSupported,
            message: "Platform 'macos' is not supported in this version.",
            configuration: .validBaseline.with { $0.product.platform = .macOS }
        ),
        ValidationTrigger(
            code: .productTypeNotSupported,
            message: "Product type 'framework' is not supported in this version.",
            configuration: .validBaseline.with { $0.product.type = .framework }
        ),
        ValidationTrigger(
            code: .architectureNotSupported,
            message: "Architecture 'clean' is not supported in this version.",
            configuration: .validBaseline.with { $0.architecture.pattern = .clean }
        ),
        ValidationTrigger(
            code: .generatorNotSupported,
            message: "Generator 'tuist' is not supported in this version.",
            configuration: .validBaseline.with { $0.generator.type = .tuist }
        ),
        ValidationTrigger(
            code: .interfaceNotSupported,
            message: "Interface 'appkit' is not supported in this version.",
            configuration: .validBaseline.with { $0.interface = .init(primary: .appKit) }
        ),
        ValidationTrigger(
            code: .deploymentTargetNotSupported,
            message: "Deployment target '12.0' is below 15.0, the minimum supported in this version.",
            configuration: .validBaseline.with { $0.product.deploymentTarget = "12.0" }
        ),
        ValidationTrigger(
            code: .uiKitRequiresIOS,
            message: "UIKit is only available for iOS projects.",
            configuration: .validBaseline.with {
                $0.product.platform = .macOS
                $0.interface = .init(primary: .uiKit)
            }
        ),
        ValidationTrigger(
            code: .appKitRequiresMacOS,
            message: "AppKit is only available for macOS projects.",
            configuration: .validBaseline.with { $0.interface = .init(primary: .appKit) }
        ),
        ValidationTrigger(
            code: .swiftUILifecycleRequiresSwiftUI,
            message: "Lifecycle 'swiftui' requires SwiftUI as the primary interface, but it is UIKit.",
            configuration: .validBaseline.with {
                $0.interface = .init(primary: .uiKit, lifecycle: .swiftUI)
            }
        ),
        ValidationTrigger(
            code: .sceneDelegateRequiresUIKit,
            message: "Lifecycle 'app-delegate-scene-delegate' requires UIKit as the primary "
                + "interface, but it is SwiftUI.",
            configuration: .validBaseline.with {
                $0.interface = .init(primary: .swiftUI, lifecycle: .appDelegateSceneDelegate)
            }
        ),
        ValidationTrigger(
            code: .appDelegateRequiresAppKit,
            message: "Lifecycle 'app-delegate' requires AppKit as the primary interface, "
                + "but it is UIKit.",
            configuration: .validBaseline.with {
                $0.interface = .init(primary: .uiKit, lifecycle: .appDelegate)
            }
        ),
        ValidationTrigger(
            code: .invalidBundleIdentifier,
            message: "Bundle identifier 'nope' is not a valid reverse-DNS string.",
            configuration: .validBaseline.with { $0.project.bundleIdentifier = "nope" }
        ),
        ValidationTrigger(
            code: .malformedDeploymentTarget,
            message: "Deployment target 'eighteen' is not a version number.",
            configuration: .validBaseline.with { $0.product.deploymentTarget = "eighteen" }
        ),
        ValidationTrigger(
            code: .invalidProjectName,
            message: "Project name '' cannot be used as an Xcode target name.",
            configuration: .validBaseline.with { $0.project.name = "" }
        ),
        ValidationTrigger(
            code: .duplicateEnvironmentName,
            message: "Environment name 'staging' is used more than once.",
            configuration: .validBaseline.with {
                $0.environments = [
                    Environment(name: "staging", configuration: "Debug"),
                    Environment(name: "staging", configuration: "Release")
                ]
            }
        ),
        ValidationTrigger(
            code: .duplicateBuildConfiguration,
            message: "Build configuration 'Debug' is used by more than one environment.",
            configuration: .validBaseline.with {
                $0.environments = [
                    Environment(name: "development", configuration: "Debug"),
                    Environment(name: "staging", configuration: "Debug")
                ]
            }
        )
    ]

    @Test("every declared code is reachable")
    func everyCodeIsReachable() {
        let covered = Set(Self.triggers.map(\.code))

        #expect(Set(ValidationCode.allCases).subtracting(covered).isEmpty)
    }

    @Test("each trigger really produces its code", arguments: Self.triggers)
    func triggerProducesItsCode(trigger: ValidationTrigger) {
        #expect(codes(trigger.configuration).contains(trigger.code))
    }

    /// Pins the exact text against the spec. Without this, a message can drift
    /// to a raw value or an internal spelling and every other test still passes.
    @Test("each code produces the documented message", arguments: Self.triggers)
    func messageMatchesTheSpec(trigger: ValidationTrigger) {
        let issue = ConfigurationValidator().validate(trigger.configuration)
            .first { $0.code == trigger.code }

        #expect(issue?.message == trigger.message)
    }

    /// The wording is the only signal a user has for telling "not built yet"
    /// from "never going to work". If an XS1xxx rule said "in this version", a
    /// user would sit and wait for a release that will never fix it.
    @Test("only capability-boundary issues say 'in this version'", arguments: Self.triggers)
    func wordingMatchesCategory(trigger: ValidationTrigger) {
        for issue in ConfigurationValidator().validate(trigger.configuration) {
            let saysThisVersion = issue.message.contains("in this version")
            #expect(saysThisVersion == (issue.code.category == ValidationCode.Category.capabilityBoundary),
                    "\(issue.code.rawValue): \(issue.message)")
        }
    }

    /// `ValidationIssue.path` is optional because a future rule may fault the
    /// document as a whole. No rule that exists today does, so all of them
    /// must set it.
    @Test("every rule in this version sets a path", arguments: Self.triggers)
    func everyIssueHasAPath(trigger: ValidationTrigger) {
        for issue in ConfigurationValidator().validate(trigger.configuration) {
            #expect(issue.path != nil, "\(issue.code.rawValue) has no path")
        }
    }

    @Test("every rule offers a suggestion", arguments: Self.triggers)
    func everyIssueHasASuggestion(trigger: ValidationTrigger) {
        for issue in ConfigurationValidator().validate(trigger.configuration) {
            #expect(issue.suggestion != nil, "\(issue.code.rawValue) has no suggestion")
        }
    }
}
