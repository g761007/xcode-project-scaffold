import Foundation
@testable import ScaffoldCore
import ScaffoldSchema
import Testing

private let destination = URL(fileURLWithPath: "/tmp/MyApp")

private func command(_ executable: String, _ arguments: [String]) -> PlannedCommand {
    PlannedCommand(executable: executable, arguments: arguments, purpose: "Do the thing")
}

private func failedCommand(_ executable: String, _ arguments: [String]) -> GenerationError {
    .commandFailed(command(executable, arguments), exitStatus: 1, output: "")
}

/// §23's other half. `ExitCodeTests` pins the number a run exits with; this
/// pins the name it exits under, the stage it reached, and the two values a
/// reader needs to act — the command that failed and the path it is about.
@Suite("What a failure reports")
struct ErrorReportTests {
    @Test("a destination that cannot be used names the tier and the directory", arguments: [
        (GenerationError.destinationNotEmpty(destination), ScaffoldErrorCode.outputDirectoryNotEmpty),
        (.destinationHasProject(destination, marker: "App.xcodeproj"), .outputDirectoryHasProject),
        (.destinationIsNotADirectory(destination), .outputPathNotADirectory),
        (.cannotReplaceDirectory(destination), .outputPathBlockedByDirectory)
    ])
    func destinations(error: GenerationError, code: ScaffoldErrorCode) {
        #expect(error.errorCode == code)
        #expect(error.relevantPath == "/tmp/MyApp")
        #expect(error.reportedPhase == .generation)
    }

    /// Which tool is missing is the whole of what the reader does next —
    /// `brew install xcodegen` and `gem install bundler` are not
    /// interchangeable — so the three §23 names it separately are separate
    /// here, and anything else falls to the general code.
    @Test("a missing tool is named by the tool", arguments: [
        ("xcodegen", ScaffoldErrorCode.xcodegenNotInstalled, ScaffoldPhase.projectGeneration),
        ("pod", .cocoapodsNotInstalled, .dependencyInstallation),
        ("bundle", .bundlerNotInstalled, .dependencyInstallation),
        ("git", .executableNotFound, .generation),
        ("xcodebuild", .executableNotFound, .buildValidation)
    ])
    func missingTools(executable: String, code: ScaffoldErrorCode, phase: ScaffoldPhase) {
        let error = GenerationError.executableNotFound(executable)

        #expect(error.errorCode == code)
        #expect(error.reportedPhase == phase)
        #expect(error.failedCommand == nil)
    }

    /// `bundle exec pod install` failing is CocoaPods failing: what the reader
    /// runs with `--verbose` is the pod install, not Bundler. `bundle install`
    /// on its own is a command that failed, and its output names the gem.
    @Test("a command that failed is named by what it was doing", arguments: [
        (failedCommand("xcodegen", ["generate"]), ScaffoldErrorCode.xcodegenFailed, ScaffoldPhase.projectGeneration),
        (failedCommand("pod", ["install"]), .podInstallFailed, .dependencyInstallation),
        (failedCommand("bundle", ["exec", "pod", "install"]), .podInstallFailed, .dependencyInstallation),
        (failedCommand("bundle", ["install"]), .commandFailed, .dependencyInstallation),
        (failedCommand("git", ["init"]), .commandFailed, .generation)
    ])
    func failedCommands(error: GenerationError, code: ScaffoldErrorCode, phase: ScaffoldPhase) {
        #expect(error.errorCode == code)
        #expect(error.reportedPhase == phase)
    }

    @Test("a failed command is reported as it would be typed")
    func commandIsQuotedForPasting() {
        let error = failedCommand("git", ["commit", "--message", "Initial commit"])

        #expect(error.failedCommand == "git commit --message 'Initial commit'")
    }

    @Test("a workspace that never appeared is a dependency failure")
    func workspace() {
        let error = GenerationError.workspaceNotProduced("MyApp.xcworkspace")

        #expect(error.errorCode == .workspaceNotGenerated)
        #expect(error.reportedPhase == .dependencyInstallation)
        #expect(error.relevantPath == "MyApp.xcworkspace")
    }

    /// Whether the destination could be cleaned up says nothing about why the
    /// run failed, so the code stays the underlying one. What changes is the
    /// path: the reader's problem is now the directory that still has files in
    /// it, not whatever the original failure was about.
    @Test("a failure that left files keeps its code and points at the leftovers")
    func leftovers() {
        let underlying = failedCommand("pod", ["install"])
        let error = GenerationError.failedLeavingFiles(underlying, in: destination)

        #expect(error.errorCode == underlying.errorCode)
        #expect(error.reportedPhase == underlying.reportedPhase)
        #expect(error.failedCommand == underlying.failedCommand)
        #expect(error.relevantPath == "/tmp/MyApp")
    }

    @Test("a path claimed twice reports the path")
    func templateConflict() {
        let error = TemplateConflictError(
            path: "App/AppDelegate.swift",
            origins: ["Shared", "Variants/ios-uikit"]
        )

        #expect(error.errorCode == .templateConflict)
        #expect(error.reportedPhase == .planning)
        #expect(error.relevantPath == "App/AppDelegate.swift")
    }

    @Test("a project that did not build reports the build command")
    func buildFailure() {
        let error = BuildValidationError(
            command: command("xcodebuild", ["build", "-scheme", "MyApp"]),
            exitStatus: 65,
            output: ""
        )

        #expect(error.errorCode == .buildValidationFailed)
        #expect(error.reportedPhase == .buildValidation)
        #expect(error.failedCommand == "xcodebuild build -scheme MyApp")
    }

    /// The message says what happened; the code and the suggestion are the
    /// contract's, printed alongside. A description that repeated either would
    /// have every failure say the same thing twice.
    @Test("the message says only what happened")
    func messagesCarryNoContractText() {
        let errors: [any ReportableError] = [
            GenerationError.destinationNotEmpty(destination),
            GenerationError.destinationHasProject(destination, marker: "App.xcodeproj"),
            GenerationError.workspaceNotProduced("MyApp.xcworkspace"),
            TemplateConflictError(path: "App/App.swift", origins: ["Shared", "Features/Widget"])
        ]

        for error in errors {
            #expect(!error.description.contains(error.errorCode.rawValue), "\(error.errorCode)")
            #expect(!error.description.contains(error.errorCode.recoverySuggestion), "\(error.errorCode)")
        }
    }

    @Test("the wire form carries the message, the command and the path")
    func wireForm() {
        let report = failedCommand("pod", ["install"]).scaffoldError

        #expect(report.code == .podInstallFailed)
        #expect(report.exitCode == .externalCommandFailure)
        #expect(report.command == "pod install")
        #expect(report.message.contains("failed with exit status 1"))
        #expect(!report.recoverySuggestion.isEmpty)
    }
}
