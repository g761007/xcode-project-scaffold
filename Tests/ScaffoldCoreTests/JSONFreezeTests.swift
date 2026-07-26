import Foundation
@testable import ScaffoldCore
import ScaffoldSchema
import Testing

/// A `CommandOutput` carrying every key it can carry, including the ones no
/// single real command produces together. It exists to be encoded: the frozen
/// path set below is read off it, so a key added anywhere under `CommandOutput`
/// appears here or fails the suite.
private let maximalOutput = CommandOutput(
    command: "generate",
    error: ScaffoldError(
        code: .podInstallFailed,
        message: "`bundle exec pod install` failed with exit status 1.",
        command: "bundle exec pod install",
        path: "/tmp/Ledger"
    ),
    issues: [
        ValidationIssue(
            severity: .warning,
            code: .deploymentTargetNotSupported,
            message: "The deployment target is below the supported floor.",
            path: "product.deploymentTarget",
            suggestion: "Raise it to 15.0."
        )
    ],
    checks: [
        EnvironmentCheck(name: "git", required: true, found: true, detail: "git version 2.54.0")
    ]
)

/// The other half: everything a success can carry. Kept apart from the failure
/// above because `CommandOutput`'s two initialisers are the two shapes — one
/// derives its exit code from an error, the other is told one — and a single
/// value cannot exercise both.
private let maximalSuccess = CommandOutput(
    command: "plan",
    exitCode: .success,
    issues: [],
    destination: "/tmp/Ledger",
    plan: PlanSummary(
        GenerationPlan(
            files: [PlannedFile(path: "README.md", contents: "# Ledger\n")],
            commands: [PlannedCommand(
                executable: "xcodegen",
                arguments: ["generate"],
                purpose: "Produce Ledger.xcodeproj from project.yml"
            )]
        ),
        overwrites: ["README.md"]
    ),
    resolvedConfiguration: ProjectConfiguration(
        project: .init(name: "Ledger", bundleIdentifier: "com.example.ledger"),
        interface: .init(primary: .swiftUI)
    ),
    capabilities: CapabilitiesDocument(
        version: "0.9.0", schemaVersions: [1], variants: ["ios-uikit"],
        platforms: ["ios"], architectures: ["minimal"],
        dependencyManagementModes: ["none"], presets: ["standard"],
        testingFrameworks: ["swift-testing"], features: []
    )
)

/// Every key a caller may find, as a dotted path. `resolvedConfiguration` stops
/// at its own root: what is under it is `scaffold.yml`'s schema, frozen by
/// `SchemaFreezeTests` against the published JSON Schema rather than twice.
private let frozenPaths: Set<String> = [
    "ok", "command", "exitCode", "message", "phase",
    "error", "error.code", "error.message", "error.exitCode",
    "error.recoverySuggestion", "error.command", "error.path",
    "issues", "issues[].severity", "issues[].code", "issues[].message",
    "issues[].path", "issues[].suggestion",
    "destination",
    "plan", "plan.files", "plan.files[].path", "plan.files[].bytes",
    "plan.commands", "plan.commands[].executable", "plan.commands[].arguments",
    "plan.commands[].purpose", "plan.overwrites",
    "checks", "checks[].name", "checks[].required", "checks[].found", "checks[].detail",
    "capabilities", "capabilities.version", "capabilities.schemaVersions",
    "capabilities.variants", "capabilities.platforms", "capabilities.architectures",
    "capabilities.dependencyManagementModes", "capabilities.presets",
    "capabilities.testingFrameworks", "capabilities.features",
    "resolvedConfiguration"
]

private func paths(in value: Any, prefix: String = "") -> Set<String> {
    var found: Set<String> = []
    if let object = value as? [String: Any] {
        for (key, child) in object {
            let path = prefix + key
            found.insert(path)
            // `resolvedConfiguration` is the schema, and the schema has its own
            // freeze. Walking into it here would pin the same thing twice and
            // fail on a schema change in the wrong suite.
            guard path != "resolvedConfiguration" else { continue }
            found.formUnion(paths(in: child, prefix: path + "."))
        }
    }
    if let array = value as? [Any], !prefix.isEmpty {
        let itemPrefix = String(prefix.dropLast()) + "[]."
        for element in array {
            found.formUnion(paths(in: element, prefix: itemPrefix))
        }
    }
    return found
}

/// The keys of the outermost object, in the order they were written.
///
/// Depth-aware, because every nested object's keys are sorted within
/// themselves and interleaving them would make a correctly sorted document
/// look unsorted. A key is a string at depth 1 that is followed by a colon —
/// a string *value* at depth 1 is followed by a comma or a brace.
private func topLevelKeys(of json: String) -> [String] {
    let characters = Array(json)
    var keys: [String] = []
    var depth = 0
    var index = 0

    while index < characters.count {
        switch characters[index] {
        case "{", "[":
            depth += 1
        case "}", "]":
            depth -= 1
        case "\"":
            var end = index + 1
            while end < characters.count, characters[end] != "\"" {
                end += characters[end] == "\\" ? 2 : 1
            }
            let isKey = end + 1 < characters.count && characters[end + 1] == ":"
            if depth == 1, isKey {
                keys.append(String(characters[(index + 1) ..< end]))
            }
            index = end
        default:
            break
        }
        index += 1
    }
    return keys
}

/// The stored properties a type declares, whatever its values are.
///
/// The encoded-output walk cannot see a key that is `nil` in every fixture —
/// which is exactly how a new optional key would slip past a freeze. `Mirror`
/// reads the declaration instead, so a property added and left unset still
/// fails. None of these types renames its keys, so a property name is the key.
private func properties(of value: Any) -> Set<String> {
    Set(Mirror(reflecting: value).children.compactMap(\.label))
}

private func decoded(_ output: CommandOutput) throws -> [String: Any] {
    let encoded = try CommandOutputEncoder().encode(output)
    return try #require(
        try JSONSerialization.jsonObject(with: Data(encoded.utf8)) as? [String: Any]
    )
}

/// The JSON freeze (#134). This is the contract machines read: an agent parses
/// it, a script branches on it, and both were written once against a shape they
/// expect to keep.
///
/// What it pins and what it deliberately does not is in `docs/contracts.md`.
@Suite("The JSON output is frozen")
struct JSONFreezeTests {
    @Test("every key a caller can meet is one it was frozen with")
    func keysAreFrozen() throws {
        let met = try paths(in: decoded(maximalOutput))
            .union(paths(in: decoded(maximalSuccess)))

        #expect(frozenPaths.subtracting(met).isEmpty, "frozen, and no output produces it")
        #expect(met.subtracting(frozenPaths).isEmpty, "produced, and not frozen")
    }

    /// The half the encoded walk above cannot do. A key added to a type and
    /// left `nil` in every fixture encodes to nothing, so only the declaration
    /// itself gives it away.
    @Test("no type in the contract has grown a property")
    func declaredPropertiesAreFrozen() {
        let frozen: [String: Set<String>] = [
            "CommandOutput": [
                "ok", "command", "exitCode", "message", "phase", "error",
                "issues", "destination", "plan", "resolvedConfiguration",
                "checks", "capabilities"
            ],
            "ScaffoldError": ["code", "message", "exitCode", "recoverySuggestion", "command", "path"],
            "PlanSummary": ["files", "commands", "overwrites"],
            "PlanSummary.File": ["path", "bytes"],
            "PlannedCommand": ["executable", "arguments", "purpose"],
            "ValidationIssue": ["severity", "code", "message", "path", "suggestion"],
            "EnvironmentCheck": ["name", "required", "found", "detail"],
            "CapabilitiesDocument": [
                "version", "schemaVersions", "variants", "platforms", "architectures",
                "dependencyManagementModes", "presets", "testingFrameworks", "features"
            ]
        ]

        let declared: [String: Set<String>] = [
            "CommandOutput": properties(of: maximalSuccess),
            "ScaffoldError": properties(of: ScaffoldError(code: .unexpectedFailure, message: "")),
            "PlanSummary": properties(of: PlanSummary(files: [], commands: [])),
            "PlanSummary.File": properties(of: PlanSummary.File(path: "", bytes: 0)),
            "PlannedCommand": properties(of: PlannedCommand(executable: "", arguments: [], purpose: "")),
            "ValidationIssue": properties(of: ValidationIssue(code: .invalidProjectName, message: "")),
            "EnvironmentCheck": properties(of: EnvironmentCheck(name: "", required: true, found: true)),
            "CapabilitiesDocument": properties(of: CapabilitiesDocument.current(version: "0.9.0"))
        ]

        for (type, expected) in frozen {
            #expect(declared[type] == expected, "\(type)")
        }
    }

    /// The three formatting rules `CommandOutputEncoder` documents as contract
    /// rather than preference. Each has a caller behind it: one line for a log,
    /// sorted keys so the contract can be pinned as text at all, and unescaped
    /// slashes so a path in an error is readable.
    @Test("the encoding rules are the ones callers were promised")
    func encodingIsFrozen() throws {
        let encoded = try CommandOutputEncoder().encode(maximalSuccess)

        #expect(!encoded.contains("\n"), "one line")
        #expect(!encoded.contains("\\/"), "slashes unescaped")

        let topLevel = topLevelKeys(of: encoded)
        #expect(topLevel == topLevel.sorted(), "keys sorted")
        #expect(topLevel.first == "capabilities", "and sorted from the start")
    }

    /// Absent, never null. A caller testing for a key's presence has to be able
    /// to trust the answer — this is the rule that lets `plan` and `issues`
    /// mean "not applicable" rather than "empty".
    @Test("a key with nothing to say is absent rather than null")
    func absentKeysAreAbsent() throws {
        let encoded = try CommandOutputEncoder().encode(
            CommandOutput(command: "validate", exitCode: .success)
        )

        #expect(!encoded.contains("null"))
        #expect(encoded == #"{"command":"validate","exitCode":0,"ok":true}"#)
    }

    /// Every string a caller may branch on, in one place. `ErrorContractTests`
    /// pins what each code means; this pins that the set has not moved.
    @Test("the vocabularies are the ones they were frozen at")
    func vocabulariesAreFrozen() {
        #expect(ScaffoldExitCode.allCases.count == 12)
        #expect(ScaffoldErrorCode.allCases.count == 25)
        #expect(ScaffoldPhase.allCases.count == 10)
        #expect(ValidationCode.allCases.count == 32)
        #expect(ValidationSeverity.allCases.count == 2)
    }

    /// Each phase encodes as its own name — the whole point of the field is
    /// that a caller can branch on it without a lookup table.
    @Test("every phase encodes as its name", arguments: ScaffoldPhase.allCases)
    func phasesEncodeAsNames(phase: ScaffoldPhase) throws {
        let encoded = try JSONEncoder().encode([phase])
        let text = try #require(String(bytes: encoded, encoding: .utf8))

        #expect(text == #"["\#(phase.rawValue)"]"#)
    }
}
