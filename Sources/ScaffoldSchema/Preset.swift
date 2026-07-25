/// A project's scale, and the set of defaults that follows from it (§17).
///
/// Orthogonal to `Variant`: a variant picks the platform and interface, a
/// preset picks how much project comes with them. Both can be given at once.
///
/// Naming one changes only fields the document leaves unstated — anything
/// written in `scaffold.yml` wins — so a preset is a starting point rather
/// than a mode the rest of the file has to work around.
public enum Preset: String, ScaffoldEnum {
    /// The bare skeleton: minimal architecture, no dependency management, no
    /// environments, no CI, and no linters. What someone learning the toolchain
    /// wants, and what a throwaway prototype wants.
    case minimal

    /// The default recommendation: MVVM with its example, SPM, Swift Testing,
    /// both linters, and development/production environments.
    case standard

    /// What a product ships on from day one: everything `standard` has, plus UI
    /// tests, three environments with their xcconfigs, a secrets example,
    /// localization, and GitHub Actions workflows.
    case production
}

extension Preset {
    /// The identity a preset's own document is resolved against before real
    /// answers replace it. Presets state no identity, platform or interface, so
    /// these values reach nothing that survives — they exist only because the
    /// schema requires a name, an identifier and an interface to decode at all.
    public static let placeholderName = "Placeholder"
    public static let placeholderBundleIdentifier = "com.example.placeholder"
}
