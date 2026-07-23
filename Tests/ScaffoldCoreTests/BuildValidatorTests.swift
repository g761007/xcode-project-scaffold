import Foundation
@testable import ScaffoldCore
import ScaffoldSchema
import Testing

private let destination = URL(fileURLWithPath: "/tmp/MyApp")

/// `--validate-build` is the one place xscaffold runs a compiler, so what it
/// runs has to be right on a machine that is not this one: §12.2 recorded that
/// naming a simulator fails wherever that runtime is not installed.
@Suite("Validating that a generated project builds")
struct BuildValidatorTests {
    @Test("the build is aimed at a destination every machine has")
    func genericDestination() throws {
        let runner = FakeProcessRunner()
        try BuildValidator(processRunner: runner).validate(.validBaseline, at: destination)

        let invocation = try #require(runner.invocations.first)
        #expect(invocation.executable == "xcodebuild")
        #expect(invocation.arguments.contains("generic/platform=iOS Simulator"))
        #expect(invocation.workingDirectory == destination)
    }

    /// The scheme has to be one the project really has — §9.1's rule decides
    /// which environment keeps the bare name — or xcodebuild fails on an
    /// argument xscaffold chose itself.
    @Test("the scheme and project are the ones that were generated")
    func namesWhatWasGenerated() throws {
        let runner = FakeProcessRunner()
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.project.name = "Bookshelf"
            $0.environments = [Environment(name: "production", configuration: "Release")]
        }

        try BuildValidator(processRunner: runner).validate(configuration, at: destination)

        let arguments = try #require(runner.invocations.first?.arguments)
        #expect(arguments.contains("Bookshelf.xcodeproj"))
        #expect(arguments.contains("Bookshelf"))
    }

    /// Both streams, because `xcodebuild -quiet` puts its diagnostics on stdout
    /// and only `** BUILD FAILED **` on stderr. Reporting one of them is how a
    /// build failure arrives with no errors in it.
    @Test("a failed build is reported with everything the compiler said")
    func failure() throws {
        let error = #expect(throws: BuildValidationError.self) {
            try BuildValidator(processRunner: FakeProcessRunner(failing: "xcodebuild"))
                .validate(.validBaseline, at: destination)
        }

        let failure = try #require(error)
        #expect(failure.exitCode == .buildValidationFailure)
        #expect(failure.description.contains("error: line 1 is wrong"))
        #expect(failure.description.contains("fatal: it did not work"))
    }

    /// Without Xcode there is no build to validate, and that is a missing
    /// requirement rather than a failed build — a different exit code, and a
    /// different thing to do about it.
    @Test("a missing xcodebuild is a missing requirement")
    func missingXcodebuild() {
        #expect(throws: GenerationError.executableNotFound("xcodebuild")) {
            try BuildValidator(processRunner: FakeProcessRunner(missing: ["xcodebuild"]))
                .validate(.validBaseline, at: destination)
        }
    }
}
