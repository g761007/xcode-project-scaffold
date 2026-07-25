import ScaffoldSchema
import Yams

/// A platform × interface combination with a name (§17.1): the four concrete
/// shapes a generated project can take, and the CLI shortcut that picks one —
/// `xscaffold new MyApp --variant ios-uikit`. In `scaffold.yml` it stays two
/// fields; the variant is only ever a way of answering both at once.
///
/// Held as Swift values rather than as `Variants/*.yml`. A variant cannot be a
/// `scaffold.yml`, because it says nothing about the project's identity, so
/// putting variants on disk would mean a second document type with its own
/// schema, decoder, validation and tests — to express, in this version, one
/// field. When a variant needs to say materially more than the schema's own
/// defaults do, that trade is worth taking again.
public struct Variant: Equatable, Sendable {
    public let name: String
    public let summary: String

    /// All a variant states beyond the schema's defaults: the platform and the
    /// interface. Everything else is already a default, and stating it twice is
    /// how the two drift apart. The deployment target and lifecycle follow from
    /// these — Product and Interface derive them.
    let platform: ApplePlatform
    let interface: UIFramework

    public static let iOSUIKit = Variant(
        name: "ios-uikit",
        summary: "iOS app, UIKit, AppDelegate and SceneDelegate",
        platform: .iOS,
        interface: .uiKit
    )

    public static let iOSSwiftUI = Variant(
        name: "ios-swiftui",
        summary: "iOS app, SwiftUI, App lifecycle",
        platform: .iOS,
        interface: .swiftUI
    )

    public static let macOSSwiftUI = Variant(
        name: "macos-swiftui",
        summary: "macOS app, SwiftUI, App lifecycle",
        platform: .macOS,
        interface: .swiftUI
    )

    public static let macOSAppKit = Variant(
        name: "macos-appkit",
        summary: "macOS app, AppKit, code-built window and menu bar",
        platform: .macOS,
        interface: .appKit
    )

    /// The order the interactive prompt offers them in, and the order the CLI
    /// lists them in when it refuses an unknown name.
    public static let all: [Variant] = [.iOSUIKit, .iOSSwiftUI, .macOSSwiftUI, .macOSAppKit]

    public static func named(_ name: String) -> Variant? {
        all.first { $0.name == name }
    }

    /// The project's identity is not part of a variant, so it arrives here.
    public func configuration(projectName: String) -> ProjectConfiguration {
        ProjectConfiguration(
            project: .init(
                name: projectName,
                bundleIdentifier: Self.bundleIdentifier(for: projectName)
            ),
            product: .init(platform: platform),
            interface: .init(primary: interface)
        )
    }

    /// The same, with a preset's defaults applied.
    ///
    /// Routed through a document rather than through values, because that is
    /// where a preset can tell a stated field from an unstated one. It also
    /// means `--preset standard` and a `scaffold.yml` saying `preset: standard`
    /// go through one mechanism instead of two that can disagree.
    ///
    /// The document states only what a variant knows — identity, platform,
    /// interface — so everything else is the preset's to fill.
    public func configuration(projectName: String, preset: Preset?) throws -> ProjectConfiguration {
        guard let preset else { return configuration(projectName: projectName) }

        return try PresetResolution.configuration(
            projectName: projectName,
            bundleIdentifier: Self.bundleIdentifier(for: projectName),
            preset: preset,
            variant: self
        )
    }

    /// The configuration a preset resolves to on its own, for the interactive
    /// flow: it collects answers rather than parsing a document, so it needs
    /// the preset applied once up front and then overlaid with what was asked.
    public static func baseConfiguration(for preset: Preset) throws -> ProjectConfiguration {
        try PresetResolution.baseConfiguration(for: preset)
    }

    /// `com.example` because there is nothing to infer a real organisation from,
    /// and a stand-in that obviously is one gets changed. It is written into the
    /// generated `scaffold.yml`, where the user can see it.
    static func bundleIdentifier(for projectName: String) -> String {
        let segment = projectName.lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        return "com.example.\(segment)"
    }
}
