import ScaffoldSchema

/// A configuration this version has no templates for.
///
/// Validation rejects these first (XS0xxx), so reaching this means a caller
/// skipped validation rather than that a user asked for something odd.
public struct TemplateNotFoundError: Error, Equatable, Sendable {
    public let message: String
}

extension TemplateNotFoundError: CustomStringConvertible {
    public var description: String {
        message
    }
}

/// One template file, before rendering.
struct TemplateFile: Equatable, Sendable {
    /// Where it will land in the generated project, with the layer prefix
    /// removed. Still holds any `{{PLACEHOLDER}}` in its name.
    var path: String
    var contents: String
}

/// Selects the template files that apply to a configuration.
///
/// Three layers, per the plan's §7.2:
///
/// - `Shared` — every project gets these, minus whatever it switched off.
/// - `Variants/<platform>-<interface>` — the application sources. Variants
///   share no source code with one another, so they are whole directories
///   rather than fragments.
/// - `Architectures/<pattern>` — a passage of prose and a diagram for the
///   README (via `architectureDescription`), and, for a pattern that ships an
///   example, source files under `<pattern>/<variant>` that replace the
///   variant's default screen (ADR-0004). It never generates empty folders or
///   unused base protocols — the first things anyone deletes from a project.
struct TemplateLibrary: Sendable {
    private let templates: [String: String]

    init(templates: [String: String] = EmbeddedTemplates.all) {
        self.templates = templates
    }

    func files(for configuration: ProjectConfiguration) throws -> [TemplateFile] {
        let variant = variantIdentifier(for: configuration)
        let specific = files(under: "Variants/\(variant)")

        guard !specific.isEmpty else {
            throw TemplateNotFoundError(message: "No templates for variant '\(variant)'.")
        }

        // The architecture example, when the project asks for one, stands in for
        // the variant's default screen: its files replace the variant's at the
        // same path and add any new ones (ADR-0004). A pattern with no example,
        // or a project that opted out, contributes nothing here — so `minimal`,
        // and any project with the example turned off, behaves exactly as before.
        let example = configuration.architecture.generatesExample
            ? files(under: "Architectures/\(configuration.architecture.pattern.rawValue)/\(variant)")
            : []

        // Ordering is settled after rendering, because rendering changes paths.
        return overlaid(files(under: "Shared") + specific, with: example)
            .filter { include($0, for: configuration) }
    }

    /// Overlay files win over base files sharing their path; everything else in
    /// both sets passes through.
    private func overlaid(_ base: [TemplateFile], with overlay: [TemplateFile]) -> [TemplateFile] {
        guard !overlay.isEmpty else { return base }
        let replaced = Set(overlay.map(\.path))
        return base.filter { !replaced.contains($0.path) } + overlay
    }

    /// The architecture's contribution to the README.
    func architectureDescription(for configuration: ProjectConfiguration) throws -> String {
        let pattern = configuration.architecture.pattern.rawValue
        guard let description = templates["Architectures/\(pattern)/architecture.md"] else {
            throw TemplateNotFoundError(message: "No description for architecture '\(pattern)'.")
        }
        return description.trimmingTrailingNewlines()
    }

    /// A project that switched something off must not be handed its
    /// configuration file anyway: a `.swiftlint.yml` in a project that asked
    /// for no linting is a puzzle, and a `Tests/` directory with no test target
    /// behind it is worse — the file is not compiled by anything.
    private func include(_ file: TemplateFile, for configuration: ProjectConfiguration) -> Bool {
        switch file.path {
        case ".swiftlint.yml": configuration.quality.swiftlint
        case ".swiftformat": configuration.quality.swiftformat
        default: !file.path.hasPrefix("Tests/") || configuration.testing.unit != .disabled
        }
    }

    private func files(under prefix: String) -> [TemplateFile] {
        templates.compactMap { key, contents in
            guard key.hasPrefix(prefix + "/") else { return nil }
            return TemplateFile(path: String(key.dropFirst(prefix.count + 1)), contents: contents)
        }
    }

    /// Straight from the schema's own spelling, so a new variant needs a
    /// directory and nothing else.
    private func variantIdentifier(for configuration: ProjectConfiguration) -> String {
        "\(configuration.product.platform.rawValue)-\(configuration.interface.primary.rawValue)"
    }
}

extension String {
    fileprivate func trimmingTrailingNewlines() -> String {
        var text = self
        while text.hasSuffix("\n") {
            text.removeLast()
        }
        return text
    }
}
