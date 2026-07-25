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

/// Issue #79: the credential in a private spec-repo URL must not surface in
/// what the binary prints — text or JSON — while the files generation writes
/// keep the original, because `pod install` needs it.
@Suite("Credential masking at the output boundary")
struct CredentialMaskingCLITests {
    private let credentialedConfiguration = """
    project:
      name: Bookshelf
      bundleIdentifier: com.example.bookshelf
    interface:
      primary: swiftui
    dependencyManagement:
      mode: cocoapods
      cocoapods:
        sources:
          - https://ci:s3cret@enterprise.example.com/specs.git
          - https://cdn.cocoapods.org/
        pods:
          - name: SnapKit
            version: "5.7.0"
    """

    @Test("plan --resolved-config masks the source URL in text and JSON")
    func planMasks() throws {
        try withTemporaryDirectory { root in
            let config = root.appendingPathComponent("scaffold.yml")
            try credentialedConfiguration.write(to: config, atomically: true, encoding: .utf8)
            let destination = root.appendingPathComponent("App").path

            let text = try xscaffold(
                "plan", "--config", config.path, "--destination", destination, "--resolved-config"
            )
            #expect(text.exitStatus == 0)
            #expect(!text.standardOutput.contains("s3cret"))
            #expect(text.standardOutput.contains("https://***@enterprise.example.com/specs.git"))

            let json = try xscaffold(
                "plan", "--config", config.path, "--destination", destination,
                "--resolved-config", "--output", "json"
            )
            #expect(!json.standardOutput.contains("s3cret"), "the whole document, not one field")
            let resolved = try #require(decoded(json).resolvedConfiguration)
            #expect(resolved.dependencyManagement.cocoapods?.sources == [
                "https://***@enterprise.example.com/specs.git",
                "https://cdn.cocoapods.org/"
            ])
        }
    }

    @Test("the written scaffold.yml and Podfile keep the original URL")
    func filesKeepTheOriginal() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("Bookshelf")
            let config = root.appendingPathComponent("scaffold.yml")
            try credentialedConfiguration.write(to: config, atomically: true, encoding: .utf8)

            let result = try xscaffold(
                "generate", "--config", config.path, "--destination", destination.path,
                "--yes", "--skip-git", "--skip-generate"
            )
            #expect(result.exitStatus == 0)
            #expect(!result.standardOutput.contains("s3cret"))

            let manifest = try String(
                contentsOf: destination.appendingPathComponent("scaffold.yml"), encoding: .utf8
            )
            let podfile = try String(
                contentsOf: destination.appendingPathComponent("Podfile"), encoding: .utf8
            )
            #expect(manifest.contains("https://ci:s3cret@enterprise.example.com/specs.git"))
            #expect(podfile.contains("source 'https://ci:s3cret@enterprise.example.com/specs.git'"))
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
