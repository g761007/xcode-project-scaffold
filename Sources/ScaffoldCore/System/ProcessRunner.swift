import Foundation

/// One external command: what to run, with what, and where.
public struct ProcessInvocation: Equatable, Sendable {
    public var executable: String
    public var arguments: [String]
    public var workingDirectory: URL

    public init(executable: String, arguments: [String], workingDirectory: URL) {
        self.executable = executable
        self.arguments = arguments
        self.workingDirectory = workingDirectory
    }
}

public struct ProcessResult: Equatable, Sendable {
    public var exitStatus: Int32
    public var standardOutput: String
    public var standardError: String

    public init(exitStatus: Int32, standardOutput: String = "", standardError: String = "") {
        self.exitStatus = exitStatus
        self.standardOutput = standardOutput
        self.standardError = standardError
    }

    public var succeeded: Bool {
        exitStatus == 0
    }

    /// Both streams, for reporting a failure.
    ///
    /// Not "stderr, or stdout if that is empty". A failing `xcodebuild -quiet`
    /// puts tens of kilobytes of diagnostics on stdout and exactly
    /// `** BUILD FAILED **` on stderr, so choosing one stream throws away the
    /// half that says what went wrong — and which half that is depends on the
    /// tool.
    public var combinedOutput: String {
        [standardOutput, standardError]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

/// The only door to the outside world (§18.2), so that a test can watch what a
/// run would execute without executing it.
public protocol ProcessRunner: Sendable {
    /// Where `executable` would be found, or `nil` if it is not installed.
    ///
    /// Separate from `run` so that a run can establish everything it needs
    /// *before* it writes anything: discovering that XcodeGen is missing after
    /// the files are in place means undoing work that never had to start.
    func locate(_ executable: String) -> URL?

    /// Throws `GenerationError.executableNotFound` when the command is not
    /// installed — a fact about the machine, not a non-zero exit status.
    func run(_ invocation: ProcessInvocation) throws -> ProcessResult
}

/// Runs commands with `Process`.
public struct SystemProcessRunner: ProcessRunner {
    public init() {}

    public func locate(_ executable: String) -> URL? {
        if executable.contains("/") {
            let url = URL(fileURLWithPath: executable)
            return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
        }

        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for directory in path.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent(executable)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    /// Output is captured through temporary files rather than pipes.
    ///
    /// A pipe holds 64 KB and then blocks the child, so both streams have to be
    /// drained while the child is still running — which needs two more threads
    /// per command and a barrier to join them. Under a parallel test run that
    /// pattern fills the cooperative thread pool with threads waiting on that
    /// barrier and the whole process stops. A file never blocks the writer, so
    /// waiting for the child is all the synchronisation there is.
    public func run(_ invocation: ProcessInvocation) throws -> ProcessResult {
        guard let executableURL = locate(invocation.executable) else {
            throw GenerationError.executableNotFound(invocation.executable)
        }

        let output = try CapturedStream()
        let error = try CapturedStream()
        defer {
            output.discard()
            error.discard()
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = invocation.arguments
        process.currentDirectoryURL = invocation.workingDirectory
        process.standardOutput = output.handle
        process.standardError = error.handle

        try process.run()
        process.waitUntilExit()

        return ProcessResult(
            exitStatus: process.terminationStatus,
            standardOutput: output.text,
            standardError: error.text
        )
    }
}

/// A file standing in for one of a child process's output streams.
private struct CapturedStream {
    let url: URL
    let handle: FileHandle

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("xscaffold-output-\(UUID().uuidString)")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        handle = try FileHandle(forWritingTo: url)
    }

    /// Read after the child has exited, so everything it wrote is already here.
    var text: String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    func discard() {
        try? handle.close()
        try? FileManager.default.removeItem(at: url)
    }
}
