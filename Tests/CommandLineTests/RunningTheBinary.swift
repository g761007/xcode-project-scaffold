import Foundation
import ScaffoldCore
import ScaffoldSchema

// MARK: - Running the real thing

/// Where `swift build` left the executable.
///
/// Found from the test bundle's own path, which the runner passes on the
/// command line, so it is right for whatever configuration and architecture
/// this run was built with. `Bundle.main` is no help: under swift-testing it is
/// the toolchain's runner, not anything belonging to this package.
private let executable: String? = {
    guard let argument = CommandLine.arguments.first(where: { $0.contains(".xctest") }),
          let bundle = argument.range(of: ".xctest")
    else { return nil }

    return URL(fileURLWithPath: String(argument[argument.startIndex ..< bundle.upperBound]))
        .deletingLastPathComponent()
        .appendingPathComponent("xscaffold")
        .path
}()

struct CannotFindTheBinary: Error, CustomStringConvertible {
    var description: String {
        "Could not work out where xscaffold was built. Run these tests with `swift test`."
    }
}

/// Runs xscaffold through the same `ProcessRunner` the tool itself uses.
///
/// Nothing here reaches for git or XcodeGen: every test that writes passes
/// `--skip-git --skip-generate`, so the suite says the same thing on a machine
/// with neither installed as it does on this one.
@discardableResult
func xscaffold(_ arguments: String..., in directory: URL? = nil) throws -> ProcessResult {
    try run(arguments, in: directory)
}

func run(_ arguments: [String], in directory: URL? = nil) throws -> ProcessResult {
    guard let executable else { throw CannotFindTheBinary() }

    return try SystemProcessRunner().run(ProcessInvocation(
        executable: executable,
        arguments: arguments,
        workingDirectory: directory ?? FileManager.default.temporaryDirectory
    ))
}

func decoded(_ result: ProcessResult) throws -> CommandOutput {
    try JSONDecoder().decode(CommandOutput.self, from: Data(result.standardOutput.utf8))
}

/// Runs xscaffold with its input closed. An interactive question must not
/// block: without a terminal to read from, `new` and an unconfirmed `generate`
/// exit rather than waiting on stdin, and this is how a test reaches that path
/// without a real one.
func xscaffoldWithoutInput(_ arguments: String...) throws -> ProcessResult {
    guard let executable else { throw CannotFindTheBinary() }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.currentDirectoryURL = FileManager.default.temporaryDirectory
    process.standardInput = FileHandle.nullDevice

    let output = Pipe()
    let error = Pipe()
    process.standardOutput = output
    process.standardError = error

    try process.run()
    process.waitUntilExit()

    // The output here is a line or two, well under a pipe's buffer, so reading
    // after the process exits cannot deadlock.
    return ProcessResult(
        exitStatus: process.terminationStatus,
        standardOutput: String(bytes: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
        standardError: String(bytes: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    )
}

func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("xscaffold-cli-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try body(root)
}

let validConfiguration = """
project:
  name: Bookshelf
  bundleIdentifier: com.example.bookshelf
interface:
  primary: swiftui
"""

let invalidConfiguration = """
project:
  name: Bookshelf
  bundleIdentifier: nope
interface:
  primary: swiftui
"""
