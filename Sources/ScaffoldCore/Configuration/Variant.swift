import ScaffoldSchema

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

    public static let all: [Variant] = [
        Variant(
            name: "ios-uikit",
            summary: "iOS app, UIKit, AppDelegate and SceneDelegate",
            platform: .iOS,
            interface: .uiKit
        ),
        Variant(
            name: "ios-swiftui",
            summary: "iOS app, SwiftUI, App lifecycle",
            platform: .iOS,
            interface: .swiftUI
        ),
        Variant(
            name: "macos-swiftui",
            summary: "macOS app, SwiftUI, App lifecycle",
            platform: .macOS,
            interface: .swiftUI
        ),
        Variant(
            name: "macos-appkit",
            summary: "macOS app, AppKit, code-built window and menu bar",
            platform: .macOS,
            interface: .appKit
        )
    ]

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

    /// `com.example` because there is nothing to infer a real organisation from,
    /// and a stand-in that obviously is one gets changed. It is written into the
    /// generated `scaffold.yml`, where the user can see it.
    static func bundleIdentifier(for projectName: String) -> String {
        let segment = projectName.lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        return "com.example.\(segment)"
    }
}
