import Foundation
import ScaffoldSchema
import Testing

/// Keeps the Skill's schema reference honest about the schema.
///
/// That document is what an agent reads before writing a `scaffold.yml`. A value
/// the schema gains and the reference never mentions is a value no agent will
/// use; a code the schema drops and the reference still lists is one an agent
/// will act on. Neither shows up in a diff of the code, and the templates have
/// a check like this for the same reason.
///
/// Only what can be checked precisely is checked. Codes are unmistakable
/// strings, and allowed values are written in backticks throughout the
/// reference. Defaults such as `18.0` and `main` are deliberately left out:
/// asserting that "main" occurs somewhere in a page of prose passes whether or
/// not the default is documented, and a test that cannot fail is worse than no
/// test at all.
@Suite("The field references")
struct SkillReferenceTests {
    /// Found relative to this file: these are documents in the repository, not
    /// resources of the package.
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // ScaffoldSchemaTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // repository root

    /// Two of them, deliberately. `docs/configuration.md` is written for a
    /// person and the Skill's copy for an agent that may not have the
    /// repository at all, so neither can be a link to the other — but a field
    /// that exists in one and not the other is a reader given the wrong
    /// answer, and every assertion below runs against both.
    static let references = [
        "docs/configuration.md",
        "Skills/xcode-project-scaffold/references/configuration-schema.md"
    ]

    /// Every closed vocabulary in `scaffold.yml`. A new one has to be added
    /// here by hand — Swift cannot be asked for every type conforming to
    /// `ScaffoldEnum` — but adding one is a deliberate act, and this list is
    /// beside the assertion that uses it.
    static let vocabularies: [(name: String, values: [String])] = [
        ("ApplePlatform", ApplePlatform.allowedValues),
        ("ProductType", ProductType.allowedValues),
        ("ProgrammingLanguage", ProgrammingLanguage.allowedValues),
        ("SwiftLanguageMode", SwiftLanguageMode.allowedValues),
        ("UIFramework", UIFramework.allowedValues),
        ("ApplicationLifecycle", ApplicationLifecycle.allowedValues),
        ("ArchitecturePattern", ArchitecturePattern.allowedValues),
        ("GeneratorKind", GeneratorKind.allowedValues),
        ("UnitTestFramework", UnitTestFramework.allowedValues),
        ("UITestFramework", UITestFramework.allowedValues),
        ("DependencyMode", DependencyMode.allowedValues),
        ("CIProvider", CIProvider.allowedValues),
        ("Preset", Preset.allowedValues)
    ]

    private func reference(_ path: String) throws -> String {
        try String(contentsOf: Self.root.appendingPathComponent(path), encoding: .utf8)
    }

    @Test("every validation code is documented", arguments: references)
    func documentsEveryCode(path: String) throws {
        let reference = try reference(path)
        let missing = ValidationCode.allCases
            .map(\.rawValue)
            .filter { !reference.contains("`\($0)`") }

        #expect(missing.isEmpty, "\(path)")
    }

    /// The other direction, which the first assertion cannot see: a code that
    /// no longer exists, still listed as though it did.
    @Test("no code it documents has since been removed", arguments: references)
    func documentsNoStaleCode(path: String) throws {
        let known = Set(ValidationCode.allCases.map(\.rawValue))
        let documented = try Set(reference(path).matches(of: /XS\d{4}/).map { String($0.output) })

        #expect(documented.subtracting(known).isEmpty, "\(path)")
    }

    /// Bare or quoted — `ios`, but `"6"`, because YAML reads that one as a
    /// number unless it is quoted and the reference has to show it as written.
    @Test("every allowed value is documented", arguments: references)
    func documentsEveryValue(path: String) throws {
        let reference = try reference(path)
        let missing = Self.vocabularies.flatMap { vocabulary in
            vocabulary.values
                .filter { !reference.contains("`\($0)`") && !reference.contains("`\"\($0)\"`") }
                .map { "\(vocabulary.name).\($0)" }
        }

        #expect(missing.isEmpty, "\(path)")
    }
}
