import ScaffoldSchema

/// Renders what `environments[].values` and `secrets` become on disk (§14):
/// one xcconfig per build configuration, the secrets pair, and the typed
/// Swift accessor. Values reach code through build settings referenced from
/// the Info.plist, so nothing here invents a second channel.
struct EnvironmentFilesRenderer: Sendable {
    /// The xcconfig for one environment: the secrets include first (so a
    /// value can override a secret's default, not the reverse), then the
    /// environment's own values, sorted for a stable diff.
    func environmentFile(for environment: Environment, includingSecrets: Bool) -> String {
        var lines: [String] = []
        if includingSecrets {
            lines.append("#include \"Secrets.xcconfig\"")
            lines.append("")
        }
        lines += environment.values.sorted { $0.key < $1.key }.map { "\($0.key) = \($0.value)" }
        return lines.joined(separator: "\n") + "\n"
    }

    /// The example file and the initial real file share this content: the
    /// example values, obviously fake, so a fresh clone builds and the values
    /// get replaced. Only the real file is git-ignored.
    func secretsFile(for secrets: Secrets) -> String {
        secrets.keys.map { "\($0.name) = \($0.example)" }.joined(separator: "\n") + "\n"
    }

    /// Typed access to every declared key, generated rather than templated
    /// because its properties are the configuration's own vocabulary.
    func appConfigurationSource(valueKeys: [String]) -> String {
        let properties = valueKeys.sorted().map { key in
            "    static let \(propertyName(for: key)): String = value(\"\(key)\")"
        }

        return """
        import Foundation

        /// Typed access to the values the active build configuration injects
        /// through the Info.plist. Generated from scaffold.yml's environments
        /// and secrets: a missing key is a configuration error, and failing
        /// loudly here beats a nil quietly travelling the app.
        enum AppConfiguration {
        \(properties.joined(separator: "\n"))

            private static func value(_ key: String) -> String {
                guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
                    fatalError("Missing \\(key) — check the active configuration's xcconfig.")
                }
                return value
            }
        }

        """
    }

    /// `API_BASE_URL` reads as `apiBaseURL`: the first word lowered, the rest
    /// capitalised — and the initialisms Swift's own guidelines keep uppercase
    /// stay that way when they are not first.
    func propertyName(for key: String) -> String {
        let words = key.split(separator: "_").map { String($0).lowercased() }
        guard let first = words.first else { return key.lowercased() }

        return ([first] + words.dropFirst().map { word in
            Self.initialisms.contains(word) ? word.uppercased() : word.capitalized
        }).joined()
    }

    private static let initialisms: Set<String> = ["api", "http", "https", "id", "ui", "uri", "url"]
}
