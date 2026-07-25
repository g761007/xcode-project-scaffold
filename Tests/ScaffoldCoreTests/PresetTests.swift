@testable import ScaffoldCore
import ScaffoldSchema
import Testing

private let coder = ConfigurationCoder()

/// The identity every document needs, so each test states only what it is
/// about. Presets never supply this — a preset describes scale, not which
/// project this is.
private func document(_ body: String) -> String {
    """
    project:
      name: Bookshelf
      bundleIdentifier: com.example.bookshelf
    interface:
      primary: swiftui
    \(body)
    """
}

/// Issue #93: `preset` — the three sets, and the fixed resolution order
/// (preset defaults → user overrides → normalization → validation).
@Suite("Presets supply what the document leaves unstated")
struct PresetResolutionTests {
    @Test("no preset changes nothing")
    func absentPresetIsInert() throws {
        let decoded = try coder.decode(document(""))

        #expect(decoded.preset == nil)
        #expect(decoded.architecture.pattern == ConfigurationDefaults.architecture)
        #expect(decoded.quality.swiftlint == ConfigurationDefaults.swiftlint)
        #expect(decoded.environments.isEmpty)
    }

    /// The case the whole mechanism exists for. `swiftlint` defaults to `true`,
    /// so a preset that wants it off has to be consulted *before* the decoder
    /// applies that default — which is why the overlay runs on the document.
    @Test("minimal switches off what the schema's own defaults switch on")
    func minimalOverridesSchemaDefaults() throws {
        let decoded = try coder.decode(document("preset: minimal"))

        #expect(decoded.quality.swiftlint == false)
        #expect(decoded.quality.swiftformat == false)
        #expect(decoded.architecture.pattern == .minimal)
        #expect(decoded.dependencyManagement.mode == .disabled)
        #expect(decoded.environments.isEmpty)
        #expect(decoded.ci == nil)
    }

    @Test("standard brings MVVM, SPM and two environments")
    func standard() throws {
        let decoded = try coder.decode(document("preset: standard"))

        #expect(decoded.architecture.pattern == .mvvm)
        #expect(decoded.architecture.generatesExample)
        #expect(decoded.dependencyManagement.mode == .spm)
        #expect(decoded.quality.swiftlint)
        #expect(decoded.environments.map(\.name) == ["development", "production"])
        #expect(decoded.testing.ui.enabled == false, "UI tests are production's, not standard's")
    }

    @Test("production brings the full product set")
    func production() throws {
        let decoded = try coder.decode(document("preset: production"))

        #expect(decoded.environments.map(\.name) == ["development", "staging", "production"])
        #expect(decoded.testing.ui.enabled)
        #expect(decoded.secrets?.keys.isEmpty == false)
        #expect(decoded.localization.languages == ["en"])
        #expect(decoded.ci?.provider == .gitHubActions)
        #expect(decoded.environments.allSatisfy { !$0.values.isEmpty }, "values are what produce xcconfigs")
    }

    @Test("the preset is recorded, not resolved away")
    func presetIsRecorded() throws {
        #expect(try coder.decode(document("preset: production")).preset == .production)
    }
}

@Suite("A stated field always beats the preset")
struct PresetOverrideTests {
    /// The direction that matters most: a preset that switches something on
    /// must not survive a document that switches it off. A merge that treated
    /// `false` as "nothing to say" would silently ignore this.
    @Test("an explicit false overrides a preset's true")
    func explicitFalseWins() throws {
        let decoded = try coder.decode(document("""
        preset: standard
        quality:
          swiftlint: false
        """))

        #expect(decoded.quality.swiftlint == false)
        #expect(decoded.quality.swiftformat, "the sibling the document did not state keeps the preset's")
    }

    @Test("an explicit true overrides a preset's false")
    func explicitTrueWins() throws {
        let decoded = try coder.decode(document("""
        preset: minimal
        quality:
          swiftlint: true
        """))

        #expect(decoded.quality.swiftlint)
        #expect(decoded.quality.swiftformat == false)
    }

    /// Sections merge key by key, so stating one field of a section does not
    /// discard the preset's other fields in it.
    @Test("stating one field of a section keeps the preset's siblings")
    func sectionsMergeKeyByKey() throws {
        let decoded = try coder.decode(document("""
        preset: standard
        architecture:
          includeExample: false
        """))

        #expect(decoded.architecture.pattern == .mvvm, "the preset's pattern survives")
        #expect(!decoded.architecture.generatesExample)
    }

    /// A list replaces rather than merges: stating `environments` is stating
    /// all of them, and anything else would leave no way to ask for fewer.
    @Test("a stated list replaces the preset's entirely")
    func listsReplace() throws {
        let decoded = try coder.decode(document("""
        preset: production
        environments:
          - name: production
            configuration: Release
        """))

        #expect(decoded.environments.map(\.name) == ["production"])
    }

    @Test("an empty list means none, not the preset's")
    func emptyListMeansNone() throws {
        let decoded = try coder.decode(document("""
        preset: production
        environments: []
        """))

        #expect(decoded.environments.isEmpty)
    }

    /// Presets state no identity, so they can never contradict it.
    @Test("identity is never touched")
    func identitySurvives() throws {
        let decoded = try coder.decode(document("preset: production"))

        #expect(decoded.project.name == "Bookshelf")
        #expect(decoded.project.bundleIdentifier == "com.example.bookshelf")
        #expect(decoded.interface.primary == .swiftUI)
    }
}

/// Spec user story 7: the enterprise CocoaPods defaults cannot live in the
/// preset document, because whether they apply depends on a mode the user may
/// override. They are supplied in normalization instead.
@Suite("Production pins CocoaPods once a project reads pods")
struct PresetNormalizationTests {
    private func decode(_ body: String) throws -> ProjectConfiguration {
        try coder.decode(document(body))
    }

    @Test("overriding production onto pods brings Bundler and a pinned version")
    func podsGetBundler() throws {
        let decoded = try decode("""
        preset: production
        dependencyManagement:
          mode: cocoapods
          cocoapods:
            pods:
              - name: SnapKit
                version: "5.7.1"
        """)

        let bundler = try #require(decoded.dependencyManagement.cocoapods?.bundler)
        #expect(bundler.enabled)
        #expect(bundler.cocoapodsVersion == ConfigurationDefaults.pinnedCocoaPodsVersion)
    }

    @Test("mixed reads pods too")
    func mixedGetsBundler() throws {
        let decoded = try decode("""
        preset: production
        dependencyManagement:
          mode: mixed
        """)

        #expect(decoded.dependencyManagement.cocoapods?.bundler?.enabled == true)
    }

    /// The preset's own suggestion is SPM, which reads no pods — so the
    /// enterprise defaults must not appear and clutter an SPM project.
    @Test("production on its own brings no cocoapods section")
    func spmGetsNothing() throws {
        #expect(try decode("preset: production").dependencyManagement.cocoapods == nil)
    }

    @Test("a stated bundler beats the normalized default")
    func statedBundlerWins() throws {
        let decoded = try decode("""
        preset: production
        dependencyManagement:
          mode: cocoapods
          cocoapods:
            bundler:
              enabled: true
              cocoapodsVersion: "1.15.0"
        """)

        #expect(decoded.dependencyManagement.cocoapods?.bundler?.cocoapodsVersion == "1.15.0")
    }

    /// Only production carries the enterprise defaults; standard on pods is an
    /// ordinary CocoaPods project.
    @Test("standard on pods gets no Bundler")
    func standardGetsNothing() throws {
        let decoded = try decode("""
        preset: standard
        dependencyManagement:
          mode: cocoapods
        """)

        #expect(decoded.dependencyManagement.cocoapods?.bundler == nil)
    }
}

@Suite("Every preset resolves to something generatable")
struct PresetValidityTests {
    /// Normalization and validation run after the overlay, unchanged. A preset
    /// that resolved to a configuration the tool refuses would be a preset no
    /// one could use.
    @Test("each preset passes validation", arguments: Preset.allCases)
    func presetsValidate(preset: Preset) throws {
        let decoded = try coder.decode(document("preset: \(preset.rawValue)"))

        let issues = ConfigurationValidator().validate(decoded)

        #expect(issues.isEmpty, "\(preset.rawValue): \(issues.map(\.message))")
    }

    /// The generated `scaffold.yml` is the birth certificate (ADR-0001), so a
    /// resolved document has to read back as the same configuration.
    @Test("each preset round-trips through the coder", arguments: Preset.allCases)
    func presetsRoundTrip(preset: Preset) throws {
        let decoded = try coder.decode(document("preset: \(preset.rawValue)"))

        #expect(try coder.decode(coder.encode(decoded)) == decoded)
    }

    /// An unrecognised name is the decoder's ordinary enum failure, not a
    /// silent fallback to no preset.
    @Test("an unknown preset is refused")
    func unknownPresetIsRefused() {
        #expect(throws: ConfigurationParsingError.self) {
            try coder.decode(document("preset: enormous"))
        }
    }
}
