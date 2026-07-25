import ScaffoldSchema

/// What each preset supplies, as the `scaffold.yml` it would have been written
/// as (ADR-0008).
///
/// YAML rather than Swift values on purpose: these are defaults for a document,
/// and expressing them as one keeps "stated" and "unstated" the same distinction
/// the document itself makes. A preset states a field; the user's own document
/// overrides it key by key.
///
/// Identity — name, bundle identifier, platform, interface — is deliberately
/// absent from every one of them. A preset describes scale, never which project
/// this is.
enum PresetDocuments {
    static func document(for preset: Preset) -> String {
        switch preset {
        case .minimal: minimal
        case .standard: standard
        case .production: production
        }
    }

    /// What `production` adds once a project turns out to read pods (§17): the
    /// enterprise CocoaPods defaults, which cannot live in the preset itself
    /// because they depend on a field the user may override. Applied in
    /// normalization, after the overlay, and still beaten by anything stated.
    static let enterpriseCocoaPods = """
    dependencyManagement:
      cocoapods:
        bundler:
          enabled: true
          cocoapodsVersion: '\(ConfigurationDefaults.pinnedCocoaPodsVersion)'
    """

    /// Nothing beyond a project that compiles. The linters are stated `false`
    /// rather than omitted, because omitting them would let the schema's own
    /// defaults switch them back on — which is exactly what this preset exists
    /// to avoid.
    private static let minimal = """
    architecture:
      pattern: minimal
    dependencyManagement:
      mode: none
    quality:
      swiftlint: false
      swiftformat: false
    environments: []
    """

    private static let standard = """
    architecture:
      pattern: mvvm
      includeExample: true
    dependencyManagement:
      mode: spm
    quality:
      swiftlint: true
      swiftformat: true
    testing:
      unit: swift-testing
    environments:
      - name: development
        configuration: Debug
        bundleIdentifierSuffix: .dev
        displayNameSuffix: " Dev"
      - name: production
        configuration: Release
    """

    /// The three-environment set, their xcconfigs (which follow from stating
    /// `values`), a secrets example, localization, UI tests and CI. Everything
    /// v0.5 and v0.6 added, switched on together.
    private static let production = """
    architecture:
      pattern: mvvm
      includeExample: true
    dependencyManagement:
      mode: spm
    quality:
      swiftlint: true
      swiftformat: true
    testing:
      unit: swift-testing
      ui:
        enabled: true
    localization:
      developmentLanguage: en
      languages: [en]
    secrets:
      keys:
        - name: API_KEY
          example: sk-example-not-real
    ci:
      provider: github-actions
    environments:
      - name: development
        configuration: Debug
        bundleIdentifierSuffix: .dev
        displayNameSuffix: " Dev"
        values:
          API_BASE_URL: https://dev.example.com
      - name: staging
        configuration: Staging
        bundleIdentifierSuffix: .stg
        displayNameSuffix: " STG"
        values:
          API_BASE_URL: https://staging.example.com
      - name: production
        configuration: Release
        values:
          API_BASE_URL: https://api.example.com
    """
}
