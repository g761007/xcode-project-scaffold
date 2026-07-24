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
            schemaVersions: [ConfigurationDefaults.schemaVersion],
            variants: Variant.all.map(\.name),
            platforms: ApplePlatform.allowedValues,
            architectures: ConfigurationValidator.Supported.architectures.map(\.rawValue).sorted(),
            dependencyManagementModes: DependencyMode.allowedValues,
            testingFrameworks: ConfigurationValidator.Supported.testFrameworks.map(\.rawValue).sorted(),
            features: [
                "environment-values",
                "localization",
                "secrets",
                "ui-tests"
            ]
        )
    }
}
