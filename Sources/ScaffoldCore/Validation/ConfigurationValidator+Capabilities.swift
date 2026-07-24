import Foundation
import ScaffoldSchema

// The capability boundary, apart only for file size: the same validator, the
// same two-group contract.

extension ConfigurationValidator {
    /// Everything else in the schema's domain decodes fine and is rejected
    /// here, so the message can say "not yet" instead of "unrecognised".
    /// Internal rather than private: `Capabilities` reports from these same
    /// sets, so what the validator accepts and what `capabilities` advertises
    /// cannot disagree.
    enum Supported {
        static let productTypes: Set<ProductType> = [.application]
        /// MVVM-C is supported only on UIKit; that further restriction is a
        /// separate rule (`coordinatorRequiresUIKit`), because it is a pairing,
        /// not a blanket "this pattern is unsupported".
        static let architectures: Set<ArchitecturePattern> = [.minimal, .mvvm, .mvvmCoordinator]
        static let generators: Set<GeneratorKind> = [.xcodegen]
        /// `disabled` is supported in the sense that a project can have no
        /// tests. XCTest is not: there are no templates written against it.
        static let testFrameworks: Set<UnitTestFramework> = [.swiftTesting, .disabled]

        /// Apple's own `RecommendedDeploymentTarget` for each platform on the
        /// Xcode 26 SDKs. Static on purpose — see the note on `validate`.
        static let deploymentTargets: [ApplePlatform: VersionNumber] = [
            .iOS: VersionNumber([15, 0]),
            .macOS: VersionNumber([11, 0])
        ]
    }

    func capabilityIssues(_ configuration: ProjectConfiguration) -> [ValidationIssue] {
        [
            unsupported(
                configuration.product.type, of: Supported.productTypes,
                as: "Product type", code: .productTypeNotSupported, at: "product.type"
            ),
            unsupported(
                configuration.architecture.pattern, of: Supported.architectures,
                as: "Architecture", code: .architectureNotSupported, at: "architecture.pattern"
            ),
            unsupported(
                configuration.generator.type, of: Supported.generators,
                as: "Generator", code: .generatorNotSupported, at: "generator.type"
            ),
            unsupported(
                configuration.testing.unit, of: Supported.testFrameworks,
                as: "Test framework", code: .testFrameworkNotSupported, at: "testing.unit"
            ),
            coordinatorInterfaceIssue(configuration)
        ].compactMap(\.self)
    }

    /// MVVM-C is supported, but only on UIKit — it is a UIKit navigation
    /// pattern. On SwiftUI (a router over `NavigationStack`) and on AppKit (a
    /// window-driven coordinator) the analogue is not built yet, which makes
    /// this a boundary rather than an impossibility, so it says "in this
    /// version" like the other capability codes. It fires for any non-UIKit
    /// interface.
    func coordinatorInterfaceIssue(_ configuration: ProjectConfiguration) -> ValidationIssue? {
        guard configuration.architecture.pattern == .mvvmCoordinator,
              configuration.interface.primary != .uiKit else { return nil }

        return ValidationIssue(
            code: .coordinatorRequiresUIKit,
            message: "MVVM-C is only available on UIKit in this version.",
            path: "architecture.pattern",
            suggestion: "Use the uikit interface for mvvm-c, or the mvvm architecture instead."
        )
    }

    /// Every capability-boundary issue is built here, so the "in this version"
    /// wording that distinguishes the two groups cannot be forgotten at one
    /// call site, and so that the sixth of these checks reads the same as the
    /// first.
    func unsupported<Value: RawRepresentable & Hashable>(
        _ value: Value,
        of supported: Set<Value>,
        as noun: String,
        code: ValidationCode,
        at path: String
    ) -> ValidationIssue? where Value.RawValue == String {
        guard !supported.contains(value) else { return nil }

        return ValidationIssue(
            code: code,
            message: "\(noun) '\(value.rawValue)' is not supported in this version.",
            path: path,
            suggestion: "Use \(list(supported.map(\.rawValue))) instead."
        )
    }
}
