import ScaffoldSchema

extension UIFramework {
    /// How Apple writes the name. `rawValue` is the wire format — `uikit` — and
    /// putting that in a sentence reads as a typo.
    ///
    /// Lives here rather than in `ScaffoldSchema` because it is presentation:
    /// the schema's job is the contract, not how it reads aloud.
    var displayName: String {
        switch self {
        case .uiKit: "UIKit"
        case .swiftUI: "SwiftUI"
        case .appKit: "AppKit"
        }
    }
}
