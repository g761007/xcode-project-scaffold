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
    @Test("a bare failure carries only what every output has")
    func failure() throws {
        let output = CommandOutput(
            command: "init",
            exitCode: .fileConflict,
            message: "'/tmp/MyApp' already exists and is not empty."
        )

        #expect(try encoder.encode(output) == """
        {"command":"init","exitCode":6,\
        "message":"'/tmp/MyApp' already exists and is not empty.","ok":false}
        """)
    }

    @Test("a validation failure carries the issues")
    func validationIssues() throws {
        let output = CommandOutput(
            command: "validate",
            exitCode: .validationFailure,
            message: "The configuration cannot be generated.",
            issues: [ValidationIssue(
                code: .invalidBundleIdentifier,
                message: "Bundle identifier 'nope' is not a valid reverse-DNS string.",
                path: "project.bundleIdentifier",
                suggestion: "Use two or more dot-separated segments."
            )]
        )

        #expect(try encoder.encode(output) == """
        {"command":"validate","exitCode":4,\
        "issues":[{"code":"XS1301",\
        "message":"Bundle identifier 'nope' is not a valid reverse-DNS string.",\
        "path":"project.bundleIdentifier","severity":"error",\
        "suggestion":"Use two or more dot-separated segments."}],\
        "message":"The configuration cannot be generated.","ok":false}
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

    @Test("doctor carries one entry per thing it looked for")
    func checks() throws {
        let output = CommandOutput(
            command: "doctor",
            exitCode: .environmentRequirementMissing,
            message: "xcodegen is not installed.",
            checks: [
                EnvironmentCheck(name: "git", required: true, found: true, detail: "git version 2.54.0"),
                EnvironmentCheck(name: "xcodegen", required: true, found: false)
            ]
        )

        #expect(try encoder.encode(output) == """
        {"checks":[{"detail":"git version 2.54.0","found":true,"name":"git","required":true},\
        {"found":false,"name":"xcodegen","required":true}],\
        "command":"doctor","exitCode":10,"message":"xcodegen is not installed.","ok":false}
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
