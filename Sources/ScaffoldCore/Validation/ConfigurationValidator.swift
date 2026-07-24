import Foundation
import ScaffoldSchema

/// Checks a `ProjectConfiguration` against what this version can generate and
/// against settings that are invalid in any version.
///
/// Pure by construction: no file system, no subprocesses, no look at the
/// machine. The same `scaffold.yml` must validate identically everywhere, or
/// the reproducibility promise has a hole in it. Checks that genuinely depend
/// on the machine — is this deployment target supported by *your* installed
/// SDK, is XcodeGen on the PATH — belong to `doctor`.
public struct ConfigurationValidator: Sendable {
    public init() {}

    public func validate(_ configuration: ProjectConfiguration) -> [ValidationIssue] {
        capabilityIssues(configuration)
            + interfaceIssues(configuration)
            + lifecycleIssues(configuration)
            + architectureIssues(configuration)
            + fieldIssues(configuration)
            + environmentIssues(configuration)
            + valueKeyIssues(configuration)
            + localizationIssues(configuration)
            + dependencyIssues(configuration)
    }
}

// MARK: - What this version can generate

extension ConfigurationValidator {
    /// Everything else in the schema's domain decodes fine and is rejected
    /// here, so the message can say "not yet" instead of "unrecognised".
    private enum Supported {
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

    private func capabilityIssues(_ configuration: ProjectConfiguration) -> [ValidationIssue] {
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
    private func coordinatorInterfaceIssue(_ configuration: ProjectConfiguration) -> ValidationIssue? {
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

// MARK: - Pairings that are invalid in any version

extension ConfigurationValidator {
    private func interfaceIssues(_ configuration: ProjectConfiguration) -> [ValidationIssue] {
        switch (configuration.interface.primary, configuration.product.platform) {
        case (.uiKit, .macOS):
            [ValidationIssue(
                code: .uiKitRequiresIOS,
                message: "UIKit is only available for iOS projects.",
                path: "interface.primary",
                suggestion: "Use appkit for macOS, or set product.platform to ios."
            )]

        case (.appKit, .iOS):
            [ValidationIssue(
                code: .appKitRequiresMacOS,
                message: "AppKit is only available for macOS projects.",
                path: "interface.primary",
                suggestion: "Use uikit for iOS, or set product.platform to macos."
            )]

        default:
            []
        }
    }

    private func lifecycleIssues(_ configuration: ProjectConfiguration) -> [ValidationIssue] {
        let interface = configuration.interface.primary
        let lifecycle = configuration.interface.lifecycle
        guard lifecycle != interface.impliedLifecycle else { return [] }

        let required: (code: ValidationCode, interface: UIFramework) = switch lifecycle {
        case .swiftUI: (.swiftUILifecycleRequiresSwiftUI, .swiftUI)
        case .appDelegateSceneDelegate: (.sceneDelegateRequiresUIKit, .uiKit)
        case .appDelegate: (.appDelegateRequiresAppKit, .appKit)
        }

        return [ValidationIssue(
            code: required.code,
            message: "Lifecycle '\(lifecycle.rawValue)' requires \(required.interface.displayName) "
                + "as the primary interface, but it is \(interface.displayName).",
            path: "interface.lifecycle",
            suggestion: "Remove interface.lifecycle to use "
                + "'\(interface.impliedLifecycle.rawValue)', the default for \(interface.displayName)."
        )]
    }

    /// Asking for an example from a pattern that has none is a contradiction,
    /// not a "not yet" — `minimal` is the bare skeleton and will never carry
    /// one. An unstated `includeExample` is fine: it resolves to "no example"
    /// for such a pattern. Only an explicit `true` is wrong.
    private func architectureIssues(_ configuration: ProjectConfiguration) -> [ValidationIssue] {
        guard configuration.architecture.includeExample == true,
              !configuration.architecture.pattern.hasExample else { return [] }

        return [ValidationIssue(
            code: .exampleUnavailableForArchitecture,
            message: "Architecture '\(configuration.architecture.pattern.rawValue)' has no example, "
                + "so architecture.includeExample cannot be true.",
            path: "architecture.includeExample",
            suggestion: "Remove architecture.includeExample, or choose an architecture that has "
                + "one, such as mvvm."
        )]
    }
}

// MARK: - Field values

extension ConfigurationValidator {
    private func fieldIssues(_ configuration: ProjectConfiguration) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        if !isUsableTargetName(configuration.project.name) {
            issues.append(ValidationIssue(
                code: .invalidProjectName,
                message: "Project name '\(configuration.project.name)' cannot be used as an Xcode "
                    + "target name.",
                path: "project.name",
                suggestion: "Use a name with no leading or trailing spaces, no '/', '\\' or ':', "
                    + "and not '.' or '..' — such as 'MyApp'."
            ))
        }

        issues.append(contentsOf: bundleIdentifierIssues(configuration))
        issues.append(contentsOf: deploymentTargetIssues(configuration))
        return issues
    }

    /// The base identifier and every suffixed variant, because the suffix is
    /// concatenated onto the identifier and can invalidate it on its own.
    /// Suffixes are only checked once the base itself is sound, so one typo in
    /// the base does not produce one issue per environment.
    private func bundleIdentifierIssues(_ configuration: ProjectConfiguration) -> [ValidationIssue] {
        let base = configuration.project.bundleIdentifier
        guard isReverseDNS(base) else {
            return [ValidationIssue(
                code: .invalidBundleIdentifier,
                message: "Bundle identifier '\(base)' is not a valid reverse-DNS string.",
                path: "project.bundleIdentifier",
                suggestion: reverseDNSSuggestion
            )]
        }

        return configuration.environments.enumerated().compactMap { index, environment in
            guard let suffix = environment.bundleIdentifierSuffix else { return nil }
            let combined = base + suffix
            guard !isReverseDNS(combined) else { return nil }

            return ValidationIssue(
                code: .invalidBundleIdentifier,
                message: "Environment '\(environment.name)' produces bundle identifier "
                    + "'\(combined)', which is not a valid reverse-DNS string.",
                path: "environments[\(index)].bundleIdentifierSuffix",
                suggestion: reverseDNSSuggestion
            )
        }
    }

    private func deploymentTargetIssues(_ configuration: ProjectConfiguration) -> [ValidationIssue] {
        let written = configuration.product.deploymentTarget

        // A malformed value cannot also be "too low": reporting both would send
        // the reader chasing a second problem that does not exist.
        guard let version = VersionNumber(written) else {
            return [ValidationIssue(
                code: .malformedDeploymentTarget,
                message: "Deployment target '\(written)' is not a version number.",
                path: "product.deploymentTarget",
                suggestion: "Use one to three dot-separated numbers in quotes, such as \"18.0\"."
            )]
        }

        let platform = configuration.product.platform
        guard let minimum = Supported.deploymentTargets[platform], version < minimum else { return [] }

        return [ValidationIssue(
            code: .deploymentTargetNotSupported,
            message: "Deployment target '\(written)' is below \(display(minimum)), "
                + "the minimum supported in this version.",
            path: "product.deploymentTarget",
            suggestion: "Raise product.deploymentTarget to \(display(minimum)) or later."
        )]
    }

    private var reverseDNSSuggestion: String {
        "Use two or more dot-separated segments of letters, digits and hyphens, "
            + "such as 'com.example.myapp'."
    }

    /// The name becomes both an Xcode target and a directory, so it has to
    /// survive the file system as well as the project file.
    private func isUsableTargetName(_ name: String) -> Bool {
        guard !name.isEmpty,
              name == name.trimmingCharacters(in: .whitespacesAndNewlines),
              name != ".", name != ".."
        else { return false }

        return !name.unicodeScalars.contains { scalar in
            "/\\:".unicodeScalars.contains(scalar)
                || CharacterSet.controlCharacters.contains(scalar)
        }
    }

    private func isReverseDNS(_ identifier: String) -> Bool {
        let segments = identifier.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count >= 2 else { return false }

        return segments.allSatisfy { segment in
            guard let first = segment.first, let last = segment.last else { return false }
            guard first != "-", last != "-" else { return false }
            return segment.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
        }
    }
}

// MARK: - Environments

extension ConfigurationValidator {
    private func environmentIssues(_ configuration: ProjectConfiguration) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // Case-insensitive: environment names become scheme names, and `dev`
        // and `Dev` would produce the same one. Xcode cannot hold two schemes
        // under one name, so the second would silently replace the first.
        issues += duplicates(configuration.environments.map(\.name), ignoringCase: true)
            .map { index, name in
                ValidationIssue(
                    code: .duplicateEnvironmentName,
                    message: "Environment name '\(name)' is used more than once.",
                    path: "environments[\(index)].name",
                    suggestion: "Give each environment a name that differs by more than its casing."
                )
            }

        // Case-sensitive: Xcode really does treat `Debug` and `debug` as
        // different build configurations, so folding them would reject a valid
        // project.
        issues += duplicates(configuration.environments.map(\.configuration), ignoringCase: false)
            .map { index, name in
                ValidationIssue(
                    code: .duplicateBuildConfiguration,
                    message: "Build configuration '\(name)' is used by more than one environment.",
                    path: "environments[\(index)].configuration",
                    suggestion: "Give each environment its own build configuration."
                )
            }

        // The name also has to survive becoming a scheme, which is a file on
        // disk.
        issues += configuration.environments.enumerated().compactMap { index, environment in
            guard !isUsableTargetName(environment.name) else { return nil }
            return ValidationIssue(
                code: .invalidProjectName,
                message: "Environment name '\(environment.name)' cannot be used in a scheme name.",
                path: "environments[\(index)].name",
                suggestion: "Use a name with no leading or trailing spaces and no '/', '\\' or ':'."
            )
        }

        return issues
    }

    /// Every repeat after the first, so five clashing environments produce four
    /// issues rather than one.
    func duplicates(
        _ values: [String],
        ignoringCase: Bool
    ) -> [(index: Int, value: String)] {
        var seen: Set<String> = []
        return values.enumerated().compactMap { index, value in
            let key = ignoringCase ? value.lowercased() : value
            return seen.insert(key).inserted ? nil : (index, value)
        }
    }
}

// MARK: - The proof

/// A `ProjectConfiguration` that is known to have passed validation.
///
/// The only way to obtain one is `ConfigurationValidator.check`, and the
/// generation entry accepts nothing else — so a configuration that skipped
/// validation cannot reach generation, by construction rather than by
/// discipline. The wrapper adds no behaviour of its own: it is proof, not a
/// second configuration type.
public struct ValidatedConfiguration: Sendable {
    public let configuration: ProjectConfiguration

    fileprivate init(_ configuration: ProjectConfiguration) {
        self.configuration = configuration
    }
}

/// What `check` decides: the configuration wrapped as proof, or the issues
/// that stopped it. Warnings travel with the valid case — they do not stop a
/// run, but they are still worth reporting.
public enum ValidationOutcome: Sendable {
    case valid(ValidatedConfiguration, warnings: [ValidationIssue])
    case invalid([ValidationIssue])
}

extension ConfigurationValidator {
    /// `validate`, with the outcome carried in the type instead of left for
    /// every caller to re-derive from severities.
    public func check(_ configuration: ProjectConfiguration) -> ValidationOutcome {
        let issues = validate(configuration)
        guard !issues.contains(where: { $0.severity == .error }) else {
            return .invalid(issues)
        }
        return .valid(ValidatedConfiguration(configuration), warnings: issues)
    }
}

// MARK: - Formatting

extension ConfigurationValidator {
    func list(_ values: [String]) -> String {
        let quoted = values.sorted().map { "'\($0)'" }
        guard quoted.count > 1 else { return quoted.first ?? "" }
        return quoted.dropLast().joined(separator: ", ") + " or " + (quoted.last ?? "")
    }

    private func display(_ version: VersionNumber) -> String {
        version.components.map(String.init).joined(separator: ".")
    }
}
