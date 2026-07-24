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

    @Test("an mvvm project that includes its example is valid")
    func mvvmWithExampleIsValid() {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.architecture = .init(pattern: .mvvm, includeExample: true)
        }

        #expect(codes(configuration).isEmpty)
    }

    /// macOS is accepted by validation now; the templates that generate it
    /// arrive with M3/M4. At this layer a macOS project is clean on either of
    /// its interfaces — SwiftUI, or AppKit with its implied app-delegate
    /// lifecycle.
    @Test("a macOS project is valid on SwiftUI and AppKit", arguments: [UIFramework.swiftUI, .appKit])
    func macOSIsValid(interface: UIFramework) {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.product.platform = .macOS
            $0.interface = .init(primary: interface)
        }

        #expect(codes(configuration).isEmpty)
    }
}

@Suite("Capability boundary — valid in the domain, not built yet")
struct CapabilityBoundaryTests {
    @Test("framework is rejected, application is not")
    func productType() {
        #expect(codes(.validBaseline.with { $0.product.type = .framework }).contains(.productTypeNotSupported))
        #expect(!codes(.validBaseline).contains(.productTypeNotSupported))
    }

    @Test("clean is rejected as an unsupported architecture")
    func unsupportedArchitecture() {
        #expect(codes(.validBaseline.with { $0.architecture.pattern = .clean })
            .contains(.architectureNotSupported))
    }

    @Test("minimal, mvvm and mvvm-c are supported architectures", arguments: [
        ArchitecturePattern.minimal, .mvvm, .mvvmCoordinator
    ])
    func supportedArchitecture(pattern: ArchitecturePattern) {
        #expect(!codes(.validBaseline.with { $0.architecture.pattern = pattern })
            .contains(.architectureNotSupported))
    }

    /// MVVM-C is supported, but only on UIKit. The baseline is UIKit, so any
    /// switch away from it — to SwiftUI, or to AppKit on macOS — should trip
    /// the rule.
    @Test("MVVM-C is rejected for SwiftUI and AppKit, accepted for UIKit")
    func coordinatorRequiresUIKit() {
        let onSwiftUI = ProjectConfiguration.validBaseline.with {
            $0.interface = .init(primary: .swiftUI)
            $0.architecture.pattern = .mvvmCoordinator
        }
        #expect(codes(onSwiftUI).contains(.coordinatorRequiresUIKit))

        let onAppKit = ProjectConfiguration.validBaseline.with {
            $0.product.platform = .macOS
            $0.interface = .init(primary: .appKit)
            $0.architecture.pattern = .mvvmCoordinator
        }
        #expect(codes(onAppKit).contains(.coordinatorRequiresUIKit))

        let onUIKit = ProjectConfiguration.validBaseline.with {
            $0.architecture.pattern = .mvvmCoordinator
        }
        #expect(!codes(onUIKit).contains(.coordinatorRequiresUIKit))
    }

    @Test("Tuist is rejected, XcodeGen is not")
    func generator() {
        #expect(codes(.validBaseline.with { $0.generator.type = .tuist }).contains(.generatorNotSupported))
        #expect(!codes(.validBaseline).contains(.generatorNotSupported))
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

    /// `minimal` has no example, so an explicit `includeExample: true` is a
    /// contradiction — never valid, unlike an unstated value, which just
    /// resolves to "no example".
    @Test("an example on minimal is rejected, an example on mvvm is not")
    func exampleUnavailableForArchitecture() {
        let rejected = ProjectConfiguration.validBaseline.with {
            $0.architecture = .init(pattern: .minimal, includeExample: true)
        }
        #expect(codes(rejected).contains(.exampleUnavailableForArchitecture))

        let allowed = ProjectConfiguration.validBaseline.with {
            $0.architecture = .init(pattern: .mvvm, includeExample: true)
        }
        #expect(!codes(allowed).contains(.exampleUnavailableForArchitecture))
    }
}
