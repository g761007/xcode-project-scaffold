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

    public func run(_ invocation: ProcessInvocation) throws -> ProcessResult {
        guard let executableURL = locate(invocation.executable) else {
            throw GenerationError.executableNotFound(invocation.executable)
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = invocation.arguments
        process.currentDirectoryURL = invocation.workingDirectory

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        try process.run()

        // Both pipes are drained on their own queue. Reading one to EOF and
        // only then the other deadlocks as soon as the child fills the second
        // pipe's buffer while we are still blocked on the first.
        let collectedOutput = CollectedData()
        let collectedError = CollectedData()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "xscaffold.process-output", attributes: .concurrent)
        queue.async(group: group) { collectedOutput.store(output.fileHandleForReading.readDataToEndOfFile()) }
        queue.async(group: group) { collectedError.store(error.fileHandleForReading.readDataToEndOfFile()) }

        process.waitUntilExit()
        group.wait()

        return ProcessResult(
            exitStatus: process.terminationStatus,
            standardOutput: collectedOutput.text,
            standardError: collectedError.text
        )
    }
}

/// Written on a background queue and read once both queues have finished.
private final class CollectedData: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func store(_ new: Data) {
        lock.lock()
        defer { lock.unlock() }
        data = new
    }

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        // Lossy on purpose, against `optional_data_string_conversion`: this is a
        // failure message on its way to the user. A tool that emits one stray
        // byte should cost them one replacement character, not the whole
        // explanation of what went wrong.
        // swiftlint:disable:next optional_data_string_conversion
        return String(decoding: data, as: UTF8.self)
    }
}
