import ScaffoldSchema

extension CapabilitiesDocument {
    /// The current binary's answer. Every list is sourced from the place the
    /// validator enforces it, so what is accepted and what is advertised
    /// cannot disagree — xctest decodes, is rejected, and is therefore not
    /// advertised. `version` arrives as a parameter because `ScaffoldVersion`
    /// is the CLI's concern.
    public static func current(version: String) -> CapabilitiesDocument {
        CapabilitiesDocument(
            version: version,
            // The versions this binary *reads*, not the one it writes. They are
            // the same number today and will not be the first time a second
            // version exists — and the recovery suggestion for
            // SCHEMA_VERSION_UNSUPPORTED sends the reader here to find out
            // which versions are accepted.
            schemaVersions: ConfigurationDefaults.supportedSchemaVersions,
            variants: Variant.all.map(\.name),
            platforms: ApplePlatform.allowedValues,
            architectures: ConfigurationValidator.Supported.architectures.map(\.rawValue).sorted(),
            dependencyManagementModes: DependencyMode.allowedValues,
            presets: Preset.allowedValues,
            testingFrameworks: ConfigurationValidator.Supported.testFrameworks.map(\.rawValue).sorted(),
            features: features
        )
    }

    /// The optional capabilities a document can turn on, each named after the
    /// section that turns it on (§19).
    ///
    /// The rule matters because this is the one list with no type behind it: a
    /// name here is a promise that a document stating that section generates
    /// something, and nothing else in the binary would notice if it stopped
    /// being true. Sourced where a source exists, which is what keeps the
    /// promise honest as the binary grows.
    ///
    /// §19 also lists `spm-dependencies` and `cocoapods`. Both are absent
    /// deliberately: `dependencyManagementModes` already answers that question,
    /// and two lists that must agree eventually do not. `secrets` is here and
    /// not in §19, which simply missed it.
    private static var features: [String] {
        ([
            "environments",
            "localization",
            "secrets",
            "ui-tests",
            CIProvider.gitHubActions.rawValue
        ] + AppExtensionKind.all.map(\.featureName))
            .sorted()
    }
}
