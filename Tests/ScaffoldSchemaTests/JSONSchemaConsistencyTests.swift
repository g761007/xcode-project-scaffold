import Foundation
import ScaffoldSchema
import Testing

/// Keeps `Schemas/scaffold.schema.json` honest about the schema (§19).
///
/// The JSON Schema is what an editor validates against while someone types;
/// a vocabulary it lists that the decoder rejects — or one it misses that the
/// decoder accepts — squiggles the wrong lines. Full JSON-Schema evaluation
/// would need a dependency; equality of the closed vocabularies and the
/// top-level keys is what actually drifts, and both are checked exactly.
@Suite("The published JSON Schema")
struct JSONSchemaConsistencyTests {
    static let path = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Schemas/scaffold.schema.json")

    private func schema() throws -> [String: Any] {
        let data = try Data(contentsOf: Self.path)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func properties(_ schema: [String: Any]) throws -> [String: Any] {
        try #require(schema["properties"] as? [String: Any])
    }

    /// Walks `properties.a.properties.b…` and returns the `enum` list at the
    /// end of the path.
    private func enumValues(at path: [String], in schema: [String: Any]) throws -> [String] {
        var node = schema
        for key in path {
            let properties = try #require(node["properties"] as? [String: Any], "\(path)")
            node = try #require(properties[key] as? [String: Any], "\(path)")
        }
        return try #require(node["enum"] as? [String], "\(path)")
    }

    @Test("the top-level keys are exactly the configuration's")
    func topLevelKeys() throws {
        let expected: Set = [
            "schemaVersion", "project", "product", "language", "interface", "architecture",
            "generator", "dependencyManagement", "environments", "secrets", "localization",
            "quality", "testing", "git"
        ]

        let keys = try Set(properties(schema()).keys)

        #expect(keys == expected)
    }

    @Test("every closed vocabulary matches the decoder's", arguments: [
        (["product", "platform"], ApplePlatform.allowedValues),
        (["product", "type"], ProductType.allowedValues),
        (["language", "primary"], ProgrammingLanguage.allowedValues),
        (["interface", "primary"], UIFramework.allowedValues),
        (["interface", "lifecycle"], ApplicationLifecycle.allowedValues),
        (["architecture", "pattern"], ArchitecturePattern.allowedValues),
        (["generator", "type"], GeneratorKind.allowedValues),
        (["dependencyManagement", "mode"], DependencyMode.allowedValues),
        (["testing", "unit"], UnitTestFramework.allowedValues),
        (["testing", "ui", "framework"], UITestFramework.allowedValues)
    ])
    func vocabularies(path: [String], expected: [String]) throws {
        let listed = try enumValues(at: path, in: schema())

        #expect(listed.sorted() == expected.sorted(), "\(path)")
    }

    @Test("the required keys are the ones the decoder requires")
    func requiredKeys() throws {
        let document = try schema()

        #expect(document["required"] as? [String] == ["project", "interface"])
        let project = try #require(properties(document)["project"] as? [String: Any])
        #expect(Set(project["required"] as? [String] ?? []) == ["name", "bundleIdentifier"])
    }
}
