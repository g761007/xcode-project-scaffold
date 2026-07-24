import ScaffoldSchema

extension ApplePlatform {
    /// How Apple writes the name. `rawValue` is the wire format — `ios` — and
    /// putting that in a sentence reads as a typo.
    ///
    /// Lives here rather than in `ScaffoldSchema` because it is presentation:
    /// the schema's job is the contract, not how it reads aloud.
    var displayName: String {
        switch self {
        case .iOS: "iOS"
        case .macOS: "macOS"
        }
    }
}
