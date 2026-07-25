import Foundation
@testable import ScaffoldCore
import ScaffoldSchema
import Testing

private let encoder = CommandOutputEncoder()

/// §12.1 pins three things, and this is one of them: the fields of the JSON
/// output. It is the surface the Skill and any script are written against, so a
/// renamed key or a field that starts arriving as `null` breaks callers that
/// cannot be found, let alone fixed.
///
/// Compared as text rather than as a decoded value, because the things most
/// likely to break a caller — a key that appears, a key that disappears, a
/// number that becomes a string — are exactly what a decode into our own types
/// would hide.
@Suite("JSON output contract")
struct CommandOutputContractTests {
    /// Absent, not null: a caller checking `"plan" in output` must not be told
    /// yes by a command that has no plan to give.
    ///
    /// §23 is the rest of it: a failure names a code, the stage it reached, the
    /// number it exits with and what to do — every time, whether or not the
    /// command had anything else to report.
    @Test("a bare failure carries the error contract and nothing else")
    func failure() throws {
        let output = CommandOutput(
            command: "generate",
            error: ScaffoldError(
                code: .outputDirectoryNotEmpty,
                message: "'/tmp/MyApp' already exists and is not empty.",
                path: "/tmp/MyApp"
            )
        )

        #expect(try encoder.encode(output) == """
        {"command":"generate",\
        "error":{"code":"OUTPUT_DIRECTORY_NOT_EMPTY","exitCode":6,\
        "message":"'/tmp/MyApp' already exists and is not empty.","path":"/tmp/MyApp",\
        "recoverySuggestion":"Choose an empty destination, or pass --force to write into this one anyway."},\
        "exitCode":6,"message":"'/tmp/MyApp' already exists and is not empty.","ok":false,\
        "phase":"generation"}
        """)
    }

    /// The command is in the error rather than only in the message, so that a
    /// caller can re-run what failed without parsing English for it.
    @Test("a failed command is carried as a value")
    func failedCommand() throws {
        let output = CommandOutput(
            command: "generate",
            error: ScaffoldError(
                code: .podInstallFailed,
                message: "`bundle exec pod install` failed with exit status 1.",
                command: "bundle exec pod install"
            )
        )

        let encoded = try encoder.encode(output)

        #expect(encoded.contains(#""command":"bundle exec pod install""#))
        #expect(encoded.contains(#""phase":"dependencyInstallation""#))
        #expect(encoded.contains(#""exitCode":8"#))
    }

    /// Success says nothing about failing. A caller that branches on the
    /// presence of `error` must not find one on a run that worked.
    @Test("a success carries no error and no phase")
    func successHasNoError() throws {
        let encoded = try encoder.encode(CommandOutput(command: "plan", exitCode: .success))

        #expect(!encoded.contains("error"))
        #expect(!encoded.contains("phase"))
    }

    @Test("a validation failure carries the issues")
    func validationIssues() throws {
        let output = CommandOutput(
            command: "validate",
            error: ScaffoldError(
                code: .configurationInvalid,
                message: "The configuration cannot be generated."
            ),
            issues: [ValidationIssue(
                code: .invalidBundleIdentifier,
                message: "Bundle identifier 'nope' is not a valid reverse-DNS string.",
                path: "project.bundleIdentifier",
                suggestion: "Use two or more dot-separated segments."
            )]
        )

        #expect(try encoder.encode(output) == """
        {"command":"validate",\
        "error":{"code":"CONFIGURATION_INVALID","exitCode":4,\
        "message":"The configuration cannot be generated.",\
        "recoverySuggestion":"Fix the issues listed above; each names the field and what it expects."},\
        "exitCode":4,\
        "issues":[{"code":"XS1301",\
        "message":"Bundle identifier 'nope' is not a valid reverse-DNS string.",\
        "path":"project.bundleIdentifier","severity":"error",\
        "suggestion":"Use two or more dot-separated segments."}],\
        "message":"The configuration cannot be generated.","ok":false,"phase":"validation"}
        """)
    }

    /// A configuration with nothing wrong with it still reports `issues`, as an
    /// empty array: "I checked and found nothing" and "I did not check" are
    /// different answers.
    @Test("a clean validation says so with an empty list")
    func noIssues() throws {
        let output = CommandOutput(command: "validate", exitCode: .success, issues: [])

        #expect(try encoder.encode(output) == """
        {"command":"validate","exitCode":0,"issues":[],"ok":true}
        """)
    }

    @Test("a plan carries paths and sizes, never contents")
    func plan() throws {
        let output = CommandOutput(
            command: "plan",
            exitCode: .success,
            destination: "/tmp/MyApp",
            plan: PlanSummary(GenerationPlan(
                files: [PlannedFile(path: "README.md", contents: "# MyApp\n")],
                commands: [PlannedCommand(
                    executable: "xcodegen",
                    arguments: ["generate"],
                    purpose: "Produce MyApp.xcodeproj from project.yml"
                )]
            ))
        )

        let encoded = try encoder.encode(output)

        #expect(encoded == """
        {"command":"plan","destination":"/tmp/MyApp","exitCode":0,"ok":true,\
        "plan":{"commands":[{"arguments":["generate"],"executable":"xcodegen",\
        "purpose":"Produce MyApp.xcodeproj from project.yml"}],\
        "files":[{"bytes":8,"path":"README.md"}]}}
        """)
    }

    /// §13.3: what a forced run would replace is part of the plan a caller
    /// approves. Absent when nothing would be — the key never arrives empty.
    @Test("a plan that would overwrite says which files, and only then")
    func overwrites() throws {
        let plan = GenerationPlan(
            files: [PlannedFile(path: "README.md", contents: "# MyApp\n")],
            commands: []
        )

        let overwriting = try encoder.encode(CommandOutput(
            command: "plan",
            exitCode: .success,
            plan: PlanSummary(plan, overwrites: ["README.md"])
        ))
        #expect(overwriting == """
        {"command":"plan","exitCode":0,"ok":true,\
        "plan":{"commands":[],"files":[{"bytes":8,"path":"README.md"}],\
        "overwrites":["README.md"]}}
        """)

        let clean = try encoder.encode(CommandOutput(
            command: "plan",
            exitCode: .success,
            plan: PlanSummary(plan, overwrites: [])
        ))
        #expect(!clean.contains("overwrites"))
    }

    /// Asserted by key rather than by the whole document: the configuration's
    /// own wire format is pinned by the YAML contract tests, and repeating a
    /// hundred lines of it here would test the same thing twice.
    @Test("the resolved configuration joins the document only when asked for")
    func resolvedConfiguration() throws {
        let configuration = ProjectConfiguration(
            project: .init(name: "App", bundleIdentifier: "com.example.app"),
            interface: .init(primary: .swiftUI)
        )

        let with = try encoder.encode(CommandOutput(
            command: "plan",
            exitCode: .success,
            resolvedConfiguration: configuration
        ))
        #expect(with.contains("\"resolvedConfiguration\":"))
        #expect(with.contains("\"bundleIdentifier\":\"com.example.app\""))

        let without = try encoder.encode(CommandOutput(command: "plan", exitCode: .success))
        #expect(!without.contains("resolvedConfiguration"))
    }

    /// Key-based like resolvedConfiguration: the lists' contents are pinned by
    /// the capabilities contract test against the real binary.
    @Test("capabilities joins the document only from its own command")
    func capabilitiesKey() throws {
        let with = try encoder.encode(CommandOutput(
            command: "capabilities",
            exitCode: .success,
            capabilities: CapabilitiesDocument(
                version: "1.0.0", schemaVersions: [1], variants: ["ios-uikit"],
                platforms: ["ios"], architectures: ["minimal"],
                dependencyManagementModes: ["none"], presets: ["standard"],
                testingFrameworks: ["swift-testing"],
                features: []
            )
        ))
        #expect(with.contains("\"capabilities\":"))
        #expect(with.contains("\"variants\":[\"ios-uikit\"]"))

        let without = try encoder.encode(CommandOutput(command: "plan", exitCode: .success))
        #expect(!without.contains("capabilities"))
    }

    @Test("doctor carries one entry per thing it looked for")
    func checks() throws {
        let output = CommandOutput(
            command: "doctor",
            error: ScaffoldError(code: .environmentRequirementMissing, message: "Not installed: xcodegen."),
            checks: [
                EnvironmentCheck(name: "git", required: true, found: true, detail: "git version 2.54.0"),
                EnvironmentCheck(name: "xcodegen", required: true, found: false)
            ]
        )

        #expect(try encoder.encode(output) == """
        {"checks":[{"detail":"git version 2.54.0","found":true,"name":"git","required":true},\
        {"found":false,"name":"xcodegen","required":true}],\
        "command":"doctor",\
        "error":{"code":"ENVIRONMENT_REQUIREMENT_MISSING","exitCode":10,\
        "message":"Not installed: xcodegen.",\
        "recoverySuggestion":"Install what is reported missing above, then run this again."},\
        "exitCode":10,"message":"Not installed: xcodegen.","ok":false,"phase":"environmentCheck"}
        """)
    }

    /// Paths are the most common value in this output and appear in almost
    /// every message; escaped slashes would make every one of them unreadable.
    @Test("slashes are not escaped")
    func slashes() throws {
        let encoded = try encoder.encode(
            CommandOutput(command: "plan", exitCode: .success, destination: "/tmp/a/b")
        )

        #expect(encoded.contains("/tmp/a/b"))
        #expect(!encoded.contains("\\/"))
    }
}
