/// A closed vocabulary in `scaffold.yml`.
///
/// Conformers get decoding that names the offending value and lists what was
/// allowed, instead of the compiler's default "cannot initialize X from invalid
/// String value y" — which tells a user nothing about their options.
public protocol ScaffoldEnum: RawRepresentable, CaseIterable, Codable, Sendable
    where RawValue == String, AllCases: Sendable {}

extension ScaffoldEnum {
    /// Every accepted value, sorted, for use in error messages.
    public static var allowedValues: [String] {
        allCases.map(\.rawValue).sorted()
    }

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let value = Self(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription:
                    "'\(raw)' is not a valid value. Allowed: \(Self.allowedValues.joined(separator: ", "))."
                )
            )
        }
        self = value
    }
}

// Values marked "not supported in v0.1" still decode. Rejecting them belongs to
// the validation layer, which can say "not supported in this version" (XS0xxx)
// rather than "unrecognised value" — a materially different message for a user
// who wants to know whether to wait or to give up.

public enum ApplePlatform: String, ScaffoldEnum {
    case iOS = "ios"
    case macOS = "macos"
}

public enum ProductType: String, ScaffoldEnum {
    case application
    case framework
}

/// Objective-C is deliberately absent. Creating a new Objective-C project is
/// not on any roadmap, so `objective-c` gets "not a valid value, allowed:
/// swift" rather than a "not supported in this version" code, which would
/// imply it is coming.
public enum ProgrammingLanguage: String, ScaffoldEnum {
    case swift
}

/// Xcode's `SWIFT_VERSION` build setting.
///
/// This is a *language mode*, not a compiler or toolchain version. `swiftc`
/// accepts only `4`, `4.2`, `5` and `6`; the 4 series is not worth supporting.
/// Writing a toolchain version such as `6.3.1` here fails the build.
public enum SwiftLanguageMode: String, ScaffoldEnum {
    case v5 = "5"
    case v6 = "6"
}

public enum UIFramework: String, ScaffoldEnum {
    case uiKit = "uikit"
    case swiftUI = "swiftui"
    case appKit = "appkit"

    /// The lifecycle a project gets when it does not state one.
    public var impliedLifecycle: ApplicationLifecycle {
        switch self {
        case .uiKit: .appDelegateSceneDelegate
        case .swiftUI: .swiftUI
        case .appKit: .appDelegate
        }
    }
}

public enum ApplicationLifecycle: String, ScaffoldEnum {
    case swiftUI = "swiftui"
    case appDelegate = "app-delegate"
    case appDelegateSceneDelegate = "app-delegate-scene-delegate"
}

public enum ArchitecturePattern: String, ScaffoldEnum {
    case minimal
    case mvvm
    case mvvmCoordinator = "mvvm-c"
    case clean

    /// Whether this pattern ships a worked example. `minimal` is the bare
    /// skeleton and has none; every other pattern replaces the app's main
    /// screen with an example built in its style. This is what an unstated
    /// `architecture.includeExample` resolves against.
    public var hasExample: Bool {
        self != .minimal
    }
}

public enum GeneratorKind: String, ScaffoldEnum {
    case xcodegen
    case tuist
}

/// UI automation is XCUITest territory whichever unit framework the project
/// chose — swift-testing has no UI automation — so the vocabulary has one
/// value. It exists as a field anyway (§15.2): the schema says what the tests
/// are written against, and a second framework can join without a new key.
public enum UITestFramework: String, ScaffoldEnum {
    case xctest
}

public enum UnitTestFramework: String, ScaffoldEnum {
    case swiftTesting = "swift-testing"
    case xctest
    /// Named `disabled` rather than `none` to stay unambiguous against
    /// `Optional.none` at the call site. The wire format is still `none`.
    case disabled = "none"
}
