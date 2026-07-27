import Foundation
@testable import ScaffoldCore
import ScaffoldSchema
import Testing
import Yams

/// Every field the schema has, stated. The counterpart to
/// `YAMLContractTests.goldenDocument`, which states only what a default
/// project needs: between them every key in `scaffold.yml` appears in a
/// document that is pinned byte for byte.
///
/// It is the encoder's own output, so it also pins key order, the quoting of
/// version-like values, and where a nested list breaks its lines. Regenerate it
/// by decoding and re-encoding — never by hand.
private let maximalDocument = """
schemaVersion: 1
project:
  name: MaximalApp
  organizationName: Example Ltd
  bundleIdentifier: com.example.maximalapp
product:
  platform: ios
  type: application
  deploymentTarget: '17.0'
language:
  primary: swift
  languageMode: '6'
interface:
  primary: swiftui
  lifecycle: swiftui
architecture:
  pattern: mvvm
  includeExample: true
generator:
  type: xcodegen
dependencyManagement:
  mode: mixed
  spm:
    packages:
    - name: swift-log
      url: https://github.com/apple/swift-log.git
      from: 1.5.0
      products:
      - name: Logging
        targets:
        - MaximalApp
  cocoapods:
    sources:
    - https://cdn.cocoapods.org/
    pods:
    - name: SnapKit
      version: 5.7.1
      subspecs:
      - Core
    bundler:
      enabled: true
      cocoapodsVersion: 1.16.2
environments:
- name: development
  configuration: Debug
  bundleIdentifierSuffix: .dev
  displayNameSuffix: ' Dev'
  values:
    API_BASE_URL: https://dev.example.com
secrets:
  keys:
  - name: API_KEY
    example: sk-example-not-real
localization:
  developmentLanguage: en
  languages:
  - en
  - ja
quality:
  swiftlint: true
  swiftformat: true
testing:
  unit: swift-testing
  ui:
    enabled: true
    framework: xctest
    launchPerformanceTest: true
git:
  defaultBranch: main
ci:
  provider: github-actions
  workflows:
    build: true
    test: true
    lint: true
extensions:
  widget:
    enabled: true
  notificationService:
    enabled: true

"""

/// The fields the maximal document cannot state, because they exclude each
/// other: a package states exactly one of `from` / `exact` / `branch` /
/// `revision`, and a pod exactly one of `version` / `git` / `path` — with `git`
/// then choosing between `tag`, `branch` and `commit`. One document per
/// alternative is the only way to pin them all, so the goldens are a set.
///
/// It also states `preset`, which nothing else pinned: re-encoding it proves
/// the resolved values survive a round trip rather than being reapplied.
private let alternativesDocument = """
schemaVersion: 1
preset: minimal
project:
  name: AlternativesApp
  organizationName: ''
  bundleIdentifier: com.example.alternativesapp
product:
  platform: ios
  type: application
  deploymentTarget: '18.0'
language:
  primary: swift
  languageMode: '6'
interface:
  primary: swiftui
  lifecycle: swiftui
architecture:
  pattern: minimal
generator:
  type: xcodegen
dependencyManagement:
  mode: mixed
  spm:
    packages:
    - name: pinned
      url: https://github.com/example/pinned.git
      exact: 1.0.0
      products:
      - name: Committed
        targets:
        - AlternativesApp
    - name: tracked
      url: https://github.com/example/tracked.git
      branch: main
      products:
      - name: Tracked
        targets:
        - AlternativesApp
    - name: frozen
      url: https://github.com/example/frozen.git
      revision: 0123456789abcdef0123456789abcdef01234567
      products:
      - name: Frozen
        targets:
        - AlternativesApp
  cocoapods:
    pods:
    - name: Tagged
      git: https://internal.example.com/tagged.git
      tag: 2.1.0
    - name: Branched
      git: https://internal.example.com/branched.git
      branch: develop
    - name: Committed
      git: https://internal.example.com/pinned.git
      commit: fedcba9876543210fedcba9876543210fedcba98
    - name: Local
      path: ../LocalKit
environments: []
localization:
  developmentLanguage: en
quality:
  swiftlint: false
  swiftformat: false
testing:
  unit: swift-testing
  ui:
    enabled: false
    framework: xctest
    launchPerformanceTest: false
git:
  defaultBranch: main

"""

private let goldenDocuments = [
    YAMLContractTests.goldenDocument,
    maximalDocument,
    alternativesDocument
]

private let schemaPath = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("Schemas/scaffold.schema.json")

/// Every property path a document may state, as `a.b[].c`.
private func paths(inJSONSchema node: [String: Any], prefix: String = "") -> Set<String> {
    var found: Set<String> = []
    for (key, value) in node["properties"] as? [String: Any] ?? [:] {
        guard let value = value as? [String: Any] else { continue }
        let path = prefix + key
        found.insert(path)
        found.formUnion(paths(inJSONSchema: value, prefix: path + "."))
        if let items = value["items"] as? [String: Any] {
            found.formUnion(paths(inJSONSchema: items, prefix: path + "[]."))
        }
    }
    return found
}

/// The same shape, read off a document rather than off the schema.
private func paths(inDocument node: Node, prefix: String = "") -> Set<String> {
    var found: Set<String> = []

    if let mapping = node.mapping {
        for (key, value) in mapping {
            guard let key = key.string else { continue }
            // A free-form map — `environments[].values` — has user-chosen keys.
            // They are values, not schema, and stop the walk.
            guard prefix != "environments[].values." else { continue }
            let path = prefix + key
            found.insert(path)
            found.formUnion(paths(inDocument: value, prefix: path + "."))
        }
    }

    // Every element, not just the first: the alternatives a list exists to
    // demonstrate — one package pinned by `exact`, the next tracking a
    // `branch` — are each in a different element.
    if let sequence = node.sequence, !prefix.isEmpty {
        let itemPrefix = String(prefix.dropLast()) + "[]."
        for element in sequence {
            found.formUnion(paths(inDocument: element, prefix: itemPrefix))
        }
    }
    return found
}

/// Every type in the schema tree, and the stored properties it declares.
///
/// Walked off a decoded golden rather than listed by hand, so the map is
/// complete by construction: a type the schema grows appears as a key the frozen
/// map below does not have, and a property it grows appears inside one.
///
/// Enums are descended into but never registered. `PackageRequirement` and
/// `PodSource` carry their wire keys in `CodingKeys` rather than in properties,
/// and those keys are pinned by `alternativesDocument`, which states every one
/// of them and round-trips byte for byte.
private func declaredProperties(of value: Any, into map: inout [String: Set<String>]) {
    let mirror = Mirror(reflecting: value)
    let qualified = String(reflecting: type(of: value))
    let module = "ScaffoldSchema."

    if mirror.displayStyle == .struct, qualified.hasPrefix(module) {
        map[String(qualified.dropFirst(module.count)), default: []]
            .formUnion(mirror.children.compactMap(\.label))
    }

    for child in mirror.children {
        declaredProperties(of: child.value, into: &map)
    }
}

/// The schema freeze, as something a test can fail rather than a label.
///
/// Freezing means every element of the contract is pinned by an assertion that
/// breaks when it changes. Before this, only a *default* configuration was
/// pinned byte for byte, so every key that appears exclusively in an optional
/// section — the whole of `dependencyManagement`, `ci`, `extensions`,
/// `secrets`, and an environment's `values` — could have been renamed with the
/// suite still green. `cocoapodsVersion` had already gone missing from the
/// published JSON Schema that way.
@Suite("The schema is frozen")
struct SchemaFreezeTests {
    private let coder = ConfigurationCoder()

    /// Byte for byte, through the real coder. A field the type stops carrying
    /// disappears from the re-encoded document; a renamed one moves; a changed
    /// default changes a value.
    @Test("every golden document round-trips unchanged", arguments: goldenDocuments.indices)
    func goldensRoundTrip(index: Int) throws {
        let golden = goldenDocuments[index]

        #expect(try coder.encode(coder.decode(golden)) == golden)
    }

    /// The completeness half. The two golden documents together have to state
    /// every path the published schema allows — otherwise a key exists that no
    /// byte-for-byte assertion has ever seen.
    @Test("every path the schema allows appears in a pinned document")
    func goldensCoverTheSchema() throws {
        let data = try Data(contentsOf: schemaPath)
        let schema = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        let allowed = paths(inJSONSchema: schema)
        var pinned: Set<String> = []
        for golden in goldenDocuments {
            let node = try Yams.compose(yaml: golden)
            try pinned.formUnion(paths(inDocument: #require(node)))
        }

        #expect(allowed.subtracting(pinned).isEmpty, "in the schema, in no golden document")
        #expect(pinned.subtracting(allowed).isEmpty, "in a golden document, not in the schema")
    }

    /// The frozen surface, as a number. It exists so that adding a field is a
    /// deliberate act with a diff line beside it rather than something that
    /// happens on the way to something else.
    @Test("the schema has the number of paths it is frozen at")
    func frozenSurfaceSize() throws {
        let data = try Data(contentsOf: schemaPath)
        let schema = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(paths(inJSONSchema: schema).count == 83)
    }

    /// The half the three assertions above cannot do, and the hole they shared.
    ///
    /// All three read encoded output. A property that is `Optional` and left
    /// unstated encodes to nothing, so the goldens round-trip unchanged, neither
    /// walk in `goldensCoverTheSchema` sees it, and 83 does not move — the field
    /// ships, usable in a `scaffold.yml`, in none of the contract.
    /// `cocoapodsVersion` reached the published schema three versions late
    /// exactly this way.
    ///
    /// `Mirror` reads the declaration instead, so the frozen surface is decided
    /// by the types rather than by what three documents happen to state.
    /// `JSONFreezeTests.declaredPropertiesAreFrozen` does this for the output
    /// contract; this is the same assertion for the input one.
    @Test("no type in the schema has grown a property")
    func declaredPropertiesAreFrozen() throws {
        let frozen: [String: Set<String>] = [
            "ProjectConfiguration": [
                "schemaVersion", "preset", "project", "product", "language", "interface",
                "architecture", "generator", "dependencyManagement", "environments", "secrets",
                "localization", "quality", "testing", "git", "ci", "extensions"
            ],
            "ProjectConfiguration.Project": ["name", "organizationName", "bundleIdentifier"],
            "ProjectConfiguration.Product": ["platform", "type", "deploymentTarget"],
            "ProjectConfiguration.Language": ["primary", "languageMode"],
            "ProjectConfiguration.Interface": ["primary", "lifecycle"],
            "ProjectConfiguration.Architecture": ["pattern", "includeExample"],
            "ProjectConfiguration.Generator": ["type"],
            "ProjectConfiguration.Quality": ["swiftlint", "swiftformat"],
            "ProjectConfiguration.Testing": ["unit", "ui"],
            "ProjectConfiguration.UITesting": ["enabled", "framework", "launchPerformanceTest"],
            "ProjectConfiguration.Git": ["defaultBranch"],
            "Environment": [
                "name", "configuration", "bundleIdentifierSuffix", "displayNameSuffix", "values"
            ],
            "Localization": ["developmentLanguage", "languages"],
            "DependencyManagement": ["mode", "spm", "cocoapods"],
            "SwiftPackageDependencies": ["packages"],
            "SwiftPackage": ["name", "url", "requirement", "products"],
            "PackageProduct": ["name", "targets"],
            "CocoaPodsDependencies": ["sources", "pods", "bundler"],
            "CocoaPodsDependencies.Bundler": ["enabled", "cocoapodsVersion"],
            "Pod": ["name", "source", "subspecs"],
            "Secrets": ["keys"],
            "Secrets.SecretKey": ["name", "example"],
            "ContinuousIntegration": ["provider", "workflows"],
            "ContinuousIntegration.Workflows": ["build", "test", "lint"],
            "AppExtensions": ["widget", "notificationService"],
            "AppExtensions.Widget": ["enabled"],
            "AppExtensions.NotificationService": ["enabled"]
        ]

        // The maximal document states every optional section and every list, so
        // decoding it reaches every type in the tree. A section it stopped
        // stating would take its type out of the walk, which the assertion on
        // the key sets below reports as a missing type rather than as silence.
        var declared: [String: Set<String>] = [:]
        try declaredProperties(of: coder.decode(maximalDocument), into: &declared)

        #expect(Set(frozen.keys).subtracting(declared.keys).isEmpty, "frozen, and not in the tree")
        #expect(Set(declared.keys).subtracting(frozen.keys).isEmpty, "in the tree, and not frozen")

        for (type, expected) in frozen where declared[type] != nil {
            #expect(declared[type] == expected, "\(type)")
        }
    }
}
