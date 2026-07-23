import ScaffoldSchema

/// A named set of `ProjectConfiguration` defaults — the non-interactive route
/// into `init` (§1.1): `xscaffold init MyApp --preset ios-uikit`.
///
/// Held as Swift values rather than as `Presets/*.yml`. A preset cannot be a
/// `scaffold.yml`, because it says nothing about the project's identity, so
/// putting presets on disk would mean a second document type with its own
/// schema, decoder, validation and tests — to express, in this version, one
/// field. When a preset needs to say materially more than the schema's own
/// defaults do, that trade is worth taking again.
public struct Preset: Equatable, Sendable {
    public let name: String
    public let summary: String

    /// The only thing this version's presets disagree about. Everything else a
    /// preset could state is already the schema's default, and stating it twice
    /// is how the two drift apart.
    let interface: UIFramework

    public static let all: [Preset] = [
        Preset(
            name: "ios-uikit",
            summary: "iOS app, UIKit, AppDelegate and SceneDelegate",
            interface: .uiKit
        ),
        Preset(
            name: "ios-swiftui",
            summary: "iOS app, SwiftUI, App lifecycle",
            interface: .swiftUI
        )
    ]

    public static func named(_ name: String) -> Preset? {
        all.first { $0.name == name }
    }

    /// The project's identity is not part of a preset, so it arrives here.
    public func configuration(projectName: String) -> ProjectConfiguration {
        ProjectConfiguration(
            project: .init(
                name: projectName,
                bundleIdentifier: Self.bundleIdentifier(for: projectName)
            ),
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
