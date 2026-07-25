import ScaffoldSchema

/// Masks credentials in spec-repository URLs (§11.4): a private source often
/// reads `https://user:token@host/...`, and that token must not reach logs,
/// error messages or JSON output. The files the user owns — `scaffold.yml`
/// and the Podfile — keep the original text; they are where the credential
/// was chosen to live, and rewriting them would break `pod install`.
public enum CredentialMasking {
    /// Replaces the URL's userinfo with `***`: `https://ci:tok@host/specs`
    /// reads `https://***@host/specs`. A URL without userinfo comes back
    /// unchanged, so masking is safe to apply unconditionally.
    public static func masked(_ url: String) -> String {
        guard let scheme = url.range(of: "://") else { return url }
        let authorityEnd = url[scheme.upperBound...].firstIndex(of: "/") ?? url.endIndex
        guard let at = url[scheme.upperBound ..< authorityEnd].lastIndex(of: "@") else { return url }
        return url.replacingCharacters(in: scheme.upperBound ..< at, with: "***")
    }

    /// The configuration as reporting shows it: the same value with every
    /// source URL masked. What generation writes stays the caller's original.
    public static func masked(_ configuration: ProjectConfiguration) -> ProjectConfiguration {
        guard var cocoapods = configuration.dependencyManagement.cocoapods, !cocoapods.sources.isEmpty else {
            return configuration
        }
        cocoapods.sources = cocoapods.sources.map(masked)
        var shown = configuration
        shown.dependencyManagement.cocoapods = cocoapods
        return shown
    }

    /// Masks rendered text — the resolved-configuration echo — by replacing
    /// each credentialed source with its masked spelling. Driven by the
    /// configuration's own list, so nothing else in the text is touched.
    public static func masked(_ text: String, for configuration: ProjectConfiguration) -> String {
        (configuration.dependencyManagement.cocoapods?.sources ?? []).reduce(text) { shown, source in
            let clean = masked(source)
            guard clean != source else { return shown }
            return shown.replacingOccurrences(of: source, with: clean)
        }
    }
}
