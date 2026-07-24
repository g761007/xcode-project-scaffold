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
            let result = try xscaffold(
                "plan", "App", "--preset", "ios-uikit",
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
            let result = try xscaffold(
                "plan", "App", "--preset", "ios-uikit",
                "--destination", root.appendingPathComponent("App").path, "--resolved-config"
            )

            #expect(result.exitStatus == 0)
            #expect(result.standardOutput.contains("Resolved configuration:"))
            #expect(result.standardOutput.contains("bundleIdentifier: com.example.app"))
        }
    }

    @Test("--resolved-config carries the configuration in JSON, and only then")
    func resolvedInJSON() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("App").path

            let with = try decoded(xscaffold(
                "plan", "App", "--preset", "ios-uikit", "--destination", destination,
                "--resolved-config", "--output", "json"
            ))
            let resolved = try #require(with.resolvedConfiguration)
            #expect(resolved.project.name == "App")
            #expect(resolved.project.bundleIdentifier == "com.example.app")

            let without = try decoded(xscaffold(
                "plan", "App", "--preset", "ios-uikit", "--destination", destination,
                "--output", "json"
            ))
            #expect(without.resolvedConfiguration == nil)
        }
    }
}
