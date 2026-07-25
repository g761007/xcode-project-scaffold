import ScaffoldSchema
import Yams

/// Applies a named preset's defaults to a document before it decodes (§17).
///
/// The whole mechanism is one overlay: the preset's document underneath, the
/// user's on top. It runs on `Yams.Node` rather than on values, because a
/// stated field and an unstated one are the same value once the decoder has
/// applied its defaults, and only the document still knows which is which
/// (ADR-0008).
public enum PresetResolution {
    /// The document to decode: unchanged when no preset is named, and the
    /// preset's own with the user's overlaid when one is.
    ///
    /// Reading the preset out of the document rather than taking it as an
    /// argument keeps `preset:` an ordinary field — one the CLI can also set,
    /// but does not have to.
    static func resolved(_ node: Node) throws -> Node {
        guard let preset = try statedPreset(in: node) else { return node }
        let defaults = try Yams.compose(yaml: PresetDocuments.document(for: preset))

        guard let defaults else { return node }
        return try normalized(overlaid(defaults, with: node), for: preset)
    }

    /// The defaults a preset can only supply once the merged document says what
    /// it is — the spec's normalization step, between the overlay and
    /// validation. `production` pins CocoaPods and runs it through Bundler, but
    /// only for a project that reads pods, which the user may have decided by
    /// overriding the mode the preset suggested.
    ///
    /// Overlaid *under* the merged document, so a project that states its own
    /// bundler settings keeps them.
    private static func normalized(_ node: Node, for preset: Preset) throws -> Node {
        guard preset == .production, readsPods(node) else { return node }
        guard let enterprise = try Yams.compose(yaml: PresetDocuments.enterpriseCocoaPods) else {
            return node
        }
        return overlaid(enterprise, with: node)
    }

    private static func readsPods(_ node: Node) -> Bool {
        let mode = node.mapping?["dependencyManagement"]?.mapping?["mode"]?.string
        return mode == DependencyMode.cocoapods.rawValue || mode == DependencyMode.mixed.rawValue
    }

    /// A preset resolved on its own, for callers that have no document — the
    /// interactive flow, which collects answers rather than parsing YAML, and
    /// `config example`, which has nobody to ask. The identity it decodes
    /// against is a placeholder for the caller to replace; a preset states none
    /// of it.
    ///
    /// No preset is an answer rather than a missing one: it asks for the
    /// schema's own defaults, which is where someone writing a `scaffold.yml`
    /// by hand starts from anyway.
    ///
    /// The variant and the dependency mode are the example's other two
    /// questions. Both default to what this has always printed — an iOS
    /// SwiftUI app, with whatever the preset says about dependencies.
    public static func baseConfiguration(
        for preset: Preset?,
        variant: Variant = .iOSSwiftUI,
        dependencyMode: DependencyMode? = nil
    ) throws -> ProjectConfiguration {
        try configuration(
            projectName: Preset.placeholderName,
            bundleIdentifier: Preset.placeholderBundleIdentifier,
            preset: preset,
            variant: variant,
            dependencyMode: dependencyMode
        )
    }

    /// The one place a set of answers becomes a document.
    ///
    /// A document rather than values, because that is the only form in which a
    /// preset can tell a stated field from an unstated one (ADR-0008) — and
    /// because it is the form the user would have written by hand, so
    /// `--variant ios-uikit` and a `scaffold.yml` saying the same thing resolve
    /// through one mechanism instead of two that can disagree.
    static func configuration(
        projectName: String,
        bundleIdentifier: String,
        preset: Preset? = nil,
        variant: Variant,
        dependencyMode: DependencyMode? = nil
    ) throws -> ProjectConfiguration {
        var document: [String: Any] = [
            "project": ["name": projectName, "bundleIdentifier": bundleIdentifier],
            "product": ["platform": variant.platform.rawValue],
            "interface": ["primary": variant.interface.rawValue]
        ]
        if let preset {
            document["preset"] = preset.rawValue
        }
        // Stated only when asked for. An unstated mode is the preset's to
        // supply, and stating the same value would take that away.
        if let dependencyMode {
            document["dependencyManagement"] = ["mode": dependencyMode.rawValue]
        }

        // Dumped rather than interpolated: a project name is arbitrary text at
        // this point — validation has not run yet — and Yams knows how to quote
        // it.
        return try ConfigurationCoder().decode(Yams.dump(object: document))
    }

    /// The `preset` field, if the document states one. An unrecognised value is
    /// left alone rather than reported here: the decoder rejects it with the
    /// same message it gives any other bad enum, and one telling of that is
    /// enough.
    private static func statedPreset(in node: Node) throws -> Preset? {
        guard let name = node.mapping?["preset"]?.string else { return nil }
        return Preset(rawValue: name)
    }

    /// The user's document over the preset's. Mappings merge key by key, so a
    /// document that states one field of a section keeps the preset's other
    /// fields; anything else replaces outright.
    ///
    /// A sequence replaces rather than appends: stating `environments` is
    /// stating all of them, and a preset that supplied three would otherwise
    /// leave no way to ask for fewer.
    private static func overlaid(_ base: Node, with overlay: Node) -> Node {
        guard let baseMapping = base.mapping, let overlayMapping = overlay.mapping else {
            return overlay
        }

        var merged = baseMapping
        for (key, value) in overlayMapping {
            merged[key] = baseMapping[key].map { overlaid($0, with: value) } ?? value
        }
        return .mapping(merged)
    }
}
