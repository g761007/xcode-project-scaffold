import Foundation
import ScaffoldCore
import ScaffoldSchema
import Testing

/// Issue #45: the preview's two Show options, as flags for the non-interactive
/// caller — `plan --files` and `plan --resolved-config`, in text and JSON.
@Suite("The plan command's long forms")
struct PlanFlagsTests {
    @Test("--files lists every file and command in text")
    func filesInText() throws {
        try withTemporaryDirectory { root in
            let config = root.appendingPathComponent("scaffold.yml")
            try validConfiguration.write(to: config, atomically: true, encoding: .utf8)
            let result = try xscaffold(
                "plan", "--config", config.path,
                "--destination", root.appendingPathComponent("App").path, "--files"
            )

            #expect(result.exitStatus == 0)
            #expect(result.standardOutput.contains("Files:"))
            #expect(result.standardOutput.contains("  project.yml"))
            #expect(result.standardOutput.contains("  scaffold.yml"))
            #expect(result.standardOutput.contains("Commands:"))
        }
    }

    @Test("--resolved-config shows the full configuration in text")
    func resolvedInText() throws {
        try withTemporaryDirectory { root in
            let config = root.appendingPathComponent("scaffold.yml")
            try validConfiguration.write(to: config, atomically: true, encoding: .utf8)
            let result = try xscaffold(
                "plan", "--config", config.path,
                "--destination", root.appendingPathComponent("App").path, "--resolved-config"
            )

            #expect(result.exitStatus == 0)
            #expect(result.standardOutput.contains("Resolved configuration:"))
            #expect(result.standardOutput.contains("bundleIdentifier: com.example.bookshelf"))
        }
    }

    @Test("--resolved-config carries the configuration in JSON, and only then")
    func resolvedInJSON() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("App").path
            let config = root.appendingPathComponent("scaffold.yml")
            try validConfiguration.write(to: config, atomically: true, encoding: .utf8)

            let with = try decoded(xscaffold(
                "plan", "--config", config.path, "--destination", destination,
                "--resolved-config", "--output", "json"
            ))
            let resolved = try #require(with.resolvedConfiguration)
            #expect(resolved.project.name == "Bookshelf")
            #expect(resolved.project.bundleIdentifier == "com.example.bookshelf")

            let without = try decoded(xscaffold(
                "plan", "--config", config.path, "--destination", destination,
                "--output", "json"
            ))
            #expect(without.resolvedConfiguration == nil)
        }
    }
}

/// Issue #67: the agent's first stop, and the annotation that gives editors
/// the schema.
@Suite("Capabilities and the schema annotation")
struct CapabilitiesTests {
    @Test("capabilities reports what this version actually generates")
    func capabilitiesJSON() throws {
        let output = try decoded(xscaffold("capabilities", "--output", "json"))

        let capabilities = try #require(output.capabilities)
        #expect(output.command == "capabilities")
        #expect(capabilities.variants.sorted()
            == ["ios-swiftui", "ios-uikit", "macos-appkit", "macos-swiftui"])
        #expect(capabilities.dependencyManagementModes.contains("mixed"))
        #expect(!capabilities.testingFrameworks.contains("xctest"),
                "what the validator rejects is not advertised")
        #expect(capabilities.schemaVersions == [1])
    }

    @Test("a generated scaffold.yml opens with the schema annotation")
    func schemaAnnotation() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("Bookshelf")
            let config = root.appendingPathComponent("scaffold.yml")
            try validConfiguration.write(to: config, atomically: true, encoding: .utf8)
            try xscaffold(
                "generate", "--config", config.path, "--destination", destination.path,
                "--yes", "--skip-git", "--skip-generate"
            )

            let manifest = try String(
                contentsOf: destination.appendingPathComponent("scaffold.yml"), encoding: .utf8
            )
            #expect(manifest.hasPrefix("# yaml-language-server: $schema="))
            #expect(manifest.contains("Schemas/scaffold.schema.json"))
        }
    }
}
