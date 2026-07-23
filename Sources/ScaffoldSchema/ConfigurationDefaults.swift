/// The value every optional field in `scaffold.yml` takes when it is omitted.
///
/// Kept in one place so that the CLI's `--help`, the Skill's schema reference
/// and the decoder cannot drift apart.
public enum ConfigurationDefaults {
    public static let schemaVersion = 1
    public static let organizationName = ""

    public static let platform = ApplePlatform.iOS
    public static let productType = ProductType.application

    /// The previous major release, not the current one. (Apple's numbering
    /// jumped from iOS 18 to iOS 26, so "18" is one release back, not eight.)
    /// New projects need a defensible floor, not the newest possible one.
    public static let deploymentTarget = "18.0"

    public static let language = ProgrammingLanguage.swift
    public static let languageMode = SwiftLanguageMode.v6

    public static let architecture = ArchitecturePattern.minimal
    public static let generator = GeneratorKind.xcodegen

    public static let swiftlint = true
    public static let swiftformat = true

    public static let unitTestFramework = UnitTestFramework.swiftTesting

    public static let defaultBranch = "main"
}
