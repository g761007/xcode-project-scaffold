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
@Suite("The Skill's schema reference")
struct SkillReferenceTests {
    /// Found relative to this file: the reference is a document in the
    /// repository, not a resource of the package.
    static let path = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // ScaffoldSchemaTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // repository root
        .appendingPathComponent("Skills/xcode-project-scaffold/references/configuration-schema.md")

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
        ("UnitTestFramework", UnitTestFramework.allowedValues)
    ]

    private func reference() throws -> String {
        try String(contentsOf: Self.path, encoding: .utf8)
    }

    @Test("every validation code is documented")
    func documentsEveryCode() throws {
        let reference = try reference()
        let missing = ValidationCode.allCases
            .map(\.rawValue)
            .filter { !reference.contains("`\($0)`") }

        #expect(missing.isEmpty)
    }

    /// The other direction, which the first assertion cannot see: a code that
    /// no longer exists, still listed as though it did.
    @Test("no code it documents has since been removed")
    func documentsNoStaleCode() throws {
        let known = Set(ValidationCode.allCases.map(\.rawValue))
        let documented = try Set(reference().matches(of: /XS\d{4}/).map { String($0.output) })

        #expect(documented.subtracting(known).isEmpty)
    }

    /// Bare or quoted — `ios`, but `"6"`, because YAML reads that one as a
    /// number unless it is quoted and the reference has to show it as written.
    @Test("every allowed value is documented")
    func documentsEveryValue() throws {
        let reference = try reference()
        let missing = Self.vocabularies.flatMap { vocabulary in
            vocabulary.values
                .filter { !reference.contains("`\($0)`") && !reference.contains("`\"\($0)\"`") }
                .map { "\(vocabulary.name).\($0)" }
        }

        #expect(missing.isEmpty)
    }
}
