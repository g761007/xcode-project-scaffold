@testable import ScaffoldCore
import ScaffoldSchema
import Testing

@Suite("A configuration this version can generate")
struct ValidConfigurationTests {
    @Test("the UIKit baseline produces no issues")
    func uiKitBaselineIsValid() {
        #expect(codes(.validBaseline).isEmpty)
    }

    @Test("the SwiftUI equivalent produces no issues")
    func swiftUIBaselineIsValid() {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.interface = .init(primary: .swiftUI)
        }

        #expect(codes(configuration).isEmpty)
    }

    @Test("three distinct environments produce no issues")
    func threeEnvironmentsAreValid() {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.environments = [
                Environment(name: "development", configuration: "Debug", bundleIdentifierSuffix: ".dev"),
                Environment(name: "staging", configuration: "Staging", bundleIdentifierSuffix: ".stg"),
                Environment(name: "production", configuration: "Release")
            ]
        }

        #expect(codes(configuration).isEmpty)
    }
}

@Suite("Capability boundary — valid in the domain, not built yet")
struct CapabilityBoundaryTests {
    @Test("macOS is rejected, iOS is not")
    func platform() {
        #expect(codes(.validBaseline.with { $0.product.platform = .macOS }).contains(.platformNotSupported))
        #expect(!codes(.validBaseline).contains(.platformNotSupported))
    }

    @Test("framework is rejected, application is not")
    func productType() {
        #expect(codes(.validBaseline.with { $0.product.type = .framework }).contains(.productTypeNotSupported))
        #expect(!codes(.validBaseline).contains(.productTypeNotSupported))
    }

    @Test("every architecture but minimal is rejected", arguments: [
        ArchitecturePattern.mvvm, .mvvmCoordinator, .clean
    ])
    func architecture(pattern: ArchitecturePattern) {
        #expect(codes(.validBaseline.with { $0.architecture.pattern = pattern })
            .contains(.architectureNotSupported))
    }

    @Test("minimal architecture is accepted")
    func minimalArchitectureIsAccepted() {
        #expect(!codes(.validBaseline).contains(.architectureNotSupported))
    }

    @Test("Tuist is rejected, XcodeGen is not")
    func generator() {
        #expect(codes(.validBaseline.with { $0.generator.type = .tuist }).contains(.generatorNotSupported))
        #expect(!codes(.validBaseline).contains(.generatorNotSupported))
    }

    @Test("AppKit is rejected, UIKit and SwiftUI are not", arguments: [UIFramework.uiKit, .swiftUI])
    func interface(accepted: UIFramework) {
        let rejected = ProjectConfiguration.validBaseline.with {
            $0.interface = .init(primary: .appKit)
        }
        #expect(codes(rejected).contains(.interfaceNotSupported))

        let allowed = ProjectConfiguration.validBaseline.with { $0.interface = .init(primary: accepted) }
        #expect(!codes(allowed).contains(.interfaceNotSupported))
    }
}

@Suite("Compatibility — never valid, in any version")
struct CompatibilityTests {
    @Test("UIKit on macOS is rejected, UIKit on iOS is not")
    func uiKitRequiresIOS() {
        let rejected = ProjectConfiguration.validBaseline.with {
            $0.product.platform = .macOS
            $0.interface = .init(primary: .uiKit)
        }
        #expect(codes(rejected).contains(.uiKitRequiresIOS))
        #expect(!codes(.validBaseline).contains(.uiKitRequiresIOS))
    }

    @Test("AppKit on iOS is rejected, AppKit on macOS is not")
    func appKitRequiresMacOS() {
        let rejected = ProjectConfiguration.validBaseline.with {
            $0.interface = .init(primary: .appKit)
        }
        #expect(codes(rejected).contains(.appKitRequiresMacOS))

        let allowed = ProjectConfiguration.validBaseline.with {
            $0.product.platform = .macOS
            $0.interface = .init(primary: .appKit)
        }
        #expect(!codes(allowed).contains(.appKitRequiresMacOS))
    }

    @Test("the SwiftUI lifecycle requires SwiftUI")
    func swiftUILifecycle() {
        let rejected = ProjectConfiguration.validBaseline.with {
            $0.interface = .init(primary: .uiKit, lifecycle: .swiftUI)
        }
        #expect(codes(rejected).contains(.swiftUILifecycleRequiresSwiftUI))

        let allowed = ProjectConfiguration.validBaseline.with {
            $0.interface = .init(primary: .swiftUI, lifecycle: .swiftUI)
        }
        #expect(!codes(allowed).contains(.swiftUILifecycleRequiresSwiftUI))
    }

    @Test("the AppDelegate + SceneDelegate lifecycle requires UIKit")
    func sceneDelegateLifecycle() {
        let rejected = ProjectConfiguration.validBaseline.with {
            $0.interface = .init(primary: .swiftUI, lifecycle: .appDelegateSceneDelegate)
        }
        #expect(codes(rejected).contains(.sceneDelegateRequiresUIKit))

        // Stated explicitly rather than leaning on the baseline's implied
        // lifecycle, so the negative case still means something if the default
        // ever changes.
        let allowed = ProjectConfiguration.validBaseline.with {
            $0.interface = .init(primary: .uiKit, lifecycle: .appDelegateSceneDelegate)
        }
        #expect(!codes(allowed).contains(.sceneDelegateRequiresUIKit))
    }

    @Test("the AppDelegate-only lifecycle requires AppKit")
    func appDelegateLifecycle() {
        let rejected = ProjectConfiguration.validBaseline.with {
            $0.interface = .init(primary: .uiKit, lifecycle: .appDelegate)
        }
        #expect(codes(rejected).contains(.appDelegateRequiresAppKit))

        let allowed = ProjectConfiguration.validBaseline.with {
            $0.product.platform = .macOS
            $0.interface = .init(primary: .appKit, lifecycle: .appDelegate)
        }
        #expect(!codes(allowed).contains(.appDelegateRequiresAppKit))
    }
}
