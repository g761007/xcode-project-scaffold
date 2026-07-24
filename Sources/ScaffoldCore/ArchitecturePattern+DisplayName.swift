import ScaffoldSchema

extension ArchitecturePattern {
    /// How the pattern is written about — the same labels the questions in
    /// `new` use, so the preview and the question that produced it agree.
    var displayName: String {
        switch self {
        case .minimal: "Minimal"
        case .mvvm: "MVVM"
        case .mvvmCoordinator: "MVVM-C"
        case .clean: "Clean"
        }
    }
}
