import Foundation
@testable import ScaffoldCore
import ScaffoldSchema
import Testing

private let plan = GenerationPlan(
    files: [
        PlannedFile(path: "App/Main.swift", contents: "print(\"hello\")\n"),
        PlannedFile(path: "README.md", contents: "# Sample\n")
    ],
    commands: []
)

private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("xscaffold-overwrite-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try body(root)
}

/// §13.3: the overwrite list a caller sees before a forced run. Asked of the
/// destination before writing — afterwards every planned path exists, which is
/// why the plan never stores it.
@Suite("What a plan would overwrite")
struct GenerationPlanOverwriteTests {
    @Test("planned paths already on disk are listed; everything else is not")
    func listsClashes() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("MyApp")
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
            try "old".write(to: destination.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
            try "kept".write(to: destination.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

            #expect(plan.overwrites(at: destination) == ["README.md"])
        }
    }

    @Test("a destination that does not exist overwrites nothing")
    func nothingThere() throws {
        try withTemporaryDirectory { root in
            #expect(plan.overwrites(at: root.appendingPathComponent("MyApp")).isEmpty)
        }
    }
}
