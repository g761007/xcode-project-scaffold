import ScaffoldSchema

extension DependencyMode {
    /// How the mode is written about — the same labels the question in `new`
    /// offers, so the preview and the question that produced it agree.
    ///
    /// `mixed` is spelled out rather than named: "mixed" says nothing to
    /// someone who has not read the schema, and the whole point of the option
    /// is that it is both of the two above it.
    var displayName: String {
        switch self {
        case .disabled: "None"
        case .spm: "Swift Package Manager"
        case .cocoapods: "CocoaPods"
        case .mixed: "SPM and CocoaPods"
        }
    }
}
