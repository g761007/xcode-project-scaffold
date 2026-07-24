/// The value every optional field in `scaffold.yml` takes when it is omitted.
///
/// Kept in one place so that the CLI's `--help`, the Skill's schema reference
/// and the decoder cannot drift apart.
public enum ConfigurationDefaults {
    public static let schemaVersion = 1
    public static let organizationName = ""

    public static let platform = ApplePlatform.iOS
    public static let productType = ProductType.application

    /// The default deployment target, resolved against the platform: iOS "18.0"
    /// has no meaning on macOS (there is no macOS 18), so each platform names
    /// its own. Both are the previous major release, not the newest — Apple's
    /// numbering jumped iOS 18 → 26 and macOS 15 → 26, so each is one release
    /// back. New projects need a defensible floor, not the newest possible one.
    public static func deploymentTarget(for platform: ApplePlatform) -> String {
        switch platform {
        case .iOS: "18.0"
        case .macOS: "15.0"
        }
    }

    public static let language = ProgrammingLanguage.swift
    public static let languageMode = SwiftLanguageMode.v6

    public static let architecture = ArchitecturePattern.minimal
    public static let generator = GeneratorKind.xcodegen

    public static let swiftlint = true
    public static let swiftformat = true

    public static let unitTestFramework = UnitTestFramework.swiftTesting

    public static let defaultBranch = "main"
}
