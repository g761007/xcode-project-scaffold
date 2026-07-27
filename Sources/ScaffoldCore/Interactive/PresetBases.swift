import ScaffoldSchema

/// The preset a run named, resolved once for every dependency mode it could
/// end up with.
///
/// The interactive flow lays answers over a resolved preset. That worked while
/// every answer was a field the preset merely supplied a default for — but the
/// dependency mode is not one of those. Under `production`, a mode of
/// `cocoapods` or `mixed` pins Bundler and a CocoaPods version during
/// normalization (ADR-0008), so the base a `cocoapods` answer belongs over is a
/// different document from the base an `spm` answer belongs over. Overwriting
/// the mode on an already-resolved base would set the field and skip the
/// overlay, generating a project subtly unlike the one `config example` prints
/// from the same arguments.
///
/// Resolving all four up front, rather than re-resolving when an answer
/// changes, is what keeps the interactive loop free of a failure it has nowhere
/// to put: the loop can only respond to a problem by re-asking a question, and
/// a preset document that will not parse is a defect in a compiled-in literal,
/// not a bad answer. Four small YAML documents, before the first question.
///
/// No preset and no stated mode means no base at all — the answers resolve
/// against the schema's own defaults, exactly as they did before any of this
/// existed.
public struct PresetBases: Sendable {
    private let bases: [DependencyMode: ProjectConfiguration]

    /// What the preset resolves to with no mode stated. Read from its own
    /// document rather than from any of the four above: each of those was
    /// resolved with a mode forced into it, so none of them can still say what
    /// the preset would have chosen on its own.
    public let suggestedMode: DependencyMode

    /// - Throws: whatever resolving the preset's own document throws, which is
    ///   a defect rather than a user error — hence here, before the questions,
    ///   where the caller still has somewhere to report it.
    public init(preset: Preset?, variant: Variant = .iOSSwiftUI) throws {
        guard preset != nil else {
            bases = [:]
            suggestedMode = ConfigurationDefaults.dependencyMode
            return
        }

        suggestedMode = try PresetResolution
            .baseConfiguration(for: preset, variant: variant)
            .dependencyManagement.mode

        var resolved: [DependencyMode: ProjectConfiguration] = [:]
        for mode in DependencyMode.allCases {
            resolved[mode] = try PresetResolution.baseConfiguration(
                for: preset, variant: variant, dependencyMode: mode
            )
        }
        bases = resolved
    }

    /// The empty set, for callers with no preset to resolve.
    public static let none = PresetBases()

    private init() {
        bases = [:]
        suggestedMode = ConfigurationDefaults.dependencyMode
    }

    /// The base a given mode's answers belong over, or nil when there is no
    /// preset — which `resolved(over:)` reads as "apply the schema's defaults".
    public subscript(mode: DependencyMode) -> ProjectConfiguration? {
        bases[mode]
    }

    /// The full configuration these answers describe.
    ///
    /// The base is chosen by the mode the answers state, so it already carries
    /// whatever normalization that mode triggers — which is why `resolved(over:)`
    /// does not need to write the mode itself.
    public func configuration(for answers: PartialProjectConfiguration) -> ProjectConfiguration {
        answers.resolved(over: self[answers.dependencyMode])
    }
}
