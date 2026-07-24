/// The subset of XcodeGen's project spec that this version generates.
///
/// Modelled here rather than imported from XcodeGen (ADR-0002): a value tree
/// keeps optional sections — environments in particular — a matter of an empty
/// array rather than of YAML merging, and lets tests compare structure instead
/// of text.
///
/// Every decision lives in this tree. The encoder that turns it into YAML
/// invents nothing, so anything a reader wonders about can be answered by
/// looking at one value rather than by reading the serialiser.
///
/// It is deliberately narrow. Anything XcodeGen can express that this does not
/// is available by editing the generated `project.yml`, which takes over as the
/// project's definitive description the moment it is written (ADR-0001).
struct XcodeGenSpec: Equatable, Sendable {
    var name: String
    /// XcodeGen's own spelling — `iOS`, not `ios`.
    var platform: String
    var deploymentTarget: String
    /// Emitted into XcodeGen's options only when it says something — a
    /// localized project, or a non-default development language.
    var developmentLanguage: String?
    var languageMode: String
    var strictConcurrency: Bool
    /// Empty means "leave XcodeGen's own Debug and Release in place".
    var configurations: [Configuration]
    /// The xcconfig each configuration reads (§14); empty means none.
    var configFiles: [ConfigFile]
    /// Remote packages, in declaration order. Empty means no packages section.
    var packages: [Package]
    var appTarget: AppTarget
    var testTarget: TestTarget?
    var uiTestTarget: UITestTarget?
    var schemes: [Scheme]

    /// The scheme Xcode selects when the project is opened. Decided where the
    /// schemes are named, so that nothing downstream has to re-derive the rule
    /// about `Release` keeping the bare project name.
    var defaultSchemeName: String

    /// `optimized` maps to XcodeGen's `debug`/`release` config type, which
    /// drives the compiler and packaging defaults Xcode applies.
    struct Configuration: Equatable, Sendable {
        var name: String
        var optimized: Bool
    }

    struct ConfigFile: Equatable, Sendable {
        var configuration: String
        var path: String
    }

    struct AppTarget: Equatable, Sendable {
        var productType: String
        var bundleIdentifier: String
        var displayName: String
        var sources: [String]
        var infoPlist: InfoPlist
        /// Only for configurations that actually differ from the base.
        var overrides: [TargetOverride]
        var packageProducts: [PackageProductDependency]
    }

    /// One remote package as XcodeGen writes it: the url, and the requirement
    /// already translated to XcodeGen's own key (`from`, `exactVersion`,
    /// `branch` or `revision`) — the builder decides, the encoder copies.
    struct Package: Equatable, Sendable {
        var name: String
        var url: String
        var requirementKey: String
        var requirementValue: String
    }

    /// One product a target links, by the package that provides it.
    struct PackageProductDependency: Equatable, Sendable {
        var packageName: String
        var productName: String
    }

    /// XcodeGen writes this file from the values here, so the project ships no
    /// Info.plist of its own: one description, in `project.yml`, rather than a
    /// second file that can drift away from it.
    struct InfoPlist: Equatable, Sendable {
        var path: String
        /// Declared environment and secret keys, each written as `KEY:
        /// $(KEY)` so the active configuration's xcconfig decides the value.
        var valueKeys: [String]
        /// iOS 14 and later can describe the launch screen inline, so the
        /// project ships no storyboard at all. Not applicable to macOS.
        var includesLaunchScreen: Bool
        /// UIKit on iOS is scene-based. SwiftUI and macOS are not.
        var includesSceneManifest: Bool
    }

    /// One environment's bundle identifier and display name, applied to a
    /// single build configuration.
    struct TargetOverride: Equatable, Sendable {
        var configuration: String
        var bundleIdentifier: String
        var displayName: String
    }

    struct TestTarget: Equatable, Sendable {
        var name: String
        var sources: [String]
        var packageProducts: [PackageProductDependency]
    }

    struct UITestTarget: Equatable, Sendable {
        var name: String
        var sources: [String]
    }

    struct Scheme: Equatable, Sendable {
        var name: String
        var runConfiguration: String
        /// Separate from `runConfiguration`, and the same for every scheme:
        /// `@testable import` needs the app module built with `-enable-testing`,
        /// which only an unoptimised configuration gets. A scheme that ran its
        /// tests against an optimised configuration would not compile them.
        var testConfiguration: String
        var archiveConfiguration: String
    }
}
