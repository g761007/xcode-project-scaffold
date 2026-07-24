import Foundation
@testable import ScaffoldCore
import ScaffoldSchema
import Testing

/// Issue #46: `--open` goes through `ProcessRunner` like every subprocess, so
/// these tests assert the invocation and never launch Xcode.
@Suite("Opening the generated project")
struct ProjectOpenerTests {
    private let configuration = ProjectConfiguration(
        project: .init(name: "Bookshelf", bundleIdentifier: "com.example.bookshelf"),
        interface: .init(primary: .swiftUI)
    )

    @Test("open is invoked on the project file, in the destination")
    func opensTheProjectFile() throws {
        let runner = FakeProcessRunner()
        let destination = URL(fileURLWithPath: "/tmp/Bookshelf")

        try ProjectOpener(processRunner: runner).open(configuration, at: destination)

        let invocation = try #require(runner.invocations.first)
        #expect(invocation.executable == "open")
        #expect(invocation.arguments == ["/tmp/Bookshelf/Bookshelf.xcodeproj"])
        #expect(invocation.workingDirectory == destination)
    }

    @Test("a failed open says the project is fine and only the opening failed")
    func failureKeepsThePointStraight() {
        let runner = FakeProcessRunner(failing: "open")
        let destination = URL(fileURLWithPath: "/tmp/Bookshelf")

        let error = #expect(throws: ProjectOpener.CouldNotOpen.self) {
            try ProjectOpener(processRunner: runner).open(configuration, at: destination)
        }

        #expect(error?.description.contains("was created") == true)
    }
}
