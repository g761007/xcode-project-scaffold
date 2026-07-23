public enum ValidationSeverity: String, Codable, Sendable, CaseIterable {
    case error
    case warning
}

/// Every code the validator can emit.
///
/// The numeric prefix is part of the contract, not decoration. `XS0xxx` means
/// "this version cannot do it yet" and `XS1xxx` means "this will never work".
/// A user who cannot tell those apart either waits for a release that will
/// never help, or abandons something that ships next month.
public enum ValidationCode: String, Codable, Sendable, CaseIterable {
    // XS0xxx — capability boundary.
    case platformNotSupported = "XS0001"
    case productTypeNotSupported = "XS0003"
    case architectureNotSupported = "XS0004"
    case generatorNotSupported = "XS0005"
    case interfaceNotSupported = "XS0006"
    /// The floor is xscaffold's own, not the SDK's, so it moves when the
    /// templates start supporting older releases. That makes it a boundary,
    /// not an impossibility.
    case deploymentTargetNotSupported = "XS0007"

    // XS10xx — platform and interface pairings.
    case uiKitRequiresIOS = "XS1001"
    case appKitRequiresMacOS = "XS1002"

    // XS11xx — lifecycle.
    case swiftUILifecycleRequiresSwiftUI = "XS1101"
    case sceneDelegateRequiresUIKit = "XS1102"
    case appDelegateRequiresAppKit = "XS1103"

    // XS13xx — field values.
    case invalidBundleIdentifier = "XS1301"
    case malformedDeploymentTarget = "XS1302"
    case invalidProjectName = "XS1304"

    // XS14xx — environments.
    case duplicateEnvironmentName = "XS1401"
    case duplicateBuildConfiguration = "XS1402"

    public enum Category: Sendable, Hashable {
        /// Valid in the domain; this version cannot generate it yet.
        case capabilityBoundary
        /// Not valid in any version.
        case permanentlyInvalid
    }

    /// Assigned explicitly rather than derived from the prefix, so that a case
    /// filed under the wrong number is a test failure rather than a silent
    /// reclassification.
    public var category: Category {
        switch self {
        case .platformNotSupported,
             .productTypeNotSupported,
             .architectureNotSupported,
             .generatorNotSupported,
             .interfaceNotSupported,
             .deploymentTargetNotSupported:
            .capabilityBoundary

        case .uiKitRequiresIOS,
             .appKitRequiresMacOS,
             .swiftUILifecycleRequiresSwiftUI,
             .sceneDelegateRequiresUIKit,
             .appDelegateRequiresAppKit,
             .invalidBundleIdentifier,
             .malformedDeploymentTarget,
             .invalidProjectName,
             .duplicateEnvironmentName,
             .duplicateBuildConfiguration:
            .permanentlyInvalid
        }
    }
}

/// One problem found in a `ProjectConfiguration`.
///
/// Validation reports every problem it finds rather than stopping at the first,
/// so a user fixing five mistakes runs the command once rather than five times.
/// That includes repeats of the same rule: three environments sharing a name
/// produce three issues, not one.
public struct ValidationIssue: Codable, Sendable, Equatable {
    public let severity: ValidationSeverity
    public let code: ValidationCode
    public let message: String

    /// Dotted path to the offending field, matching `scaffold.yml`'s structure,
    /// e.g. `interface.primary` or `environments[1].configuration`. Optional
    /// because a future rule may find fault with the document as a whole; every
    /// rule that exists today sets it.
    public let path: String?

    /// What to change. Omitted when there is no single obvious fix.
    public let suggestion: String?

    public init(
        severity: ValidationSeverity = .error,
        code: ValidationCode,
        message: String,
        path: String? = nil,
        suggestion: String? = nil
    ) {
        self.severity = severity
        self.code = code
        self.message = message
        self.path = path
        self.suggestion = suggestion
    }
}
