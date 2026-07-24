import Foundation
@testable import ScaffoldCore
import ScaffoldSchema
import Testing

private func makeConfiguration(mode: DependencyMode) -> ProjectConfiguration {
    ProjectConfiguration(
        project: .init(name: "Bookshelf", bundleIdentifier: "com.example.bookshelf"),
        interface: .init(primary: .swiftUI),
        dependencyManagement: .init(mode: mode)
    )
}

/// Issue #61: one derivation, everywhere. CocoaPods' "use the workspace" rule
/// lives here and nowhere else, and every driver — build, open, the report —
/// takes its answer from it.
@Suite("ProjectContainer picks the container")
struct ProjectContainerTests {
    @Test("none and spm drive the project file", arguments: [DependencyMode.disabled, .spm])
    func projectModes(mode: DependencyMode) {
        let container = ProjectContainer(for: makeConfiguration(mode: mode))

        #expect(container == .project(fileName: "Bookshelf.xcodeproj"))
        #expect(container.xcodebuildFlag == "-project")
    }

    @Test("cocoapods and mixed drive the workspace", arguments: [DependencyMode.cocoapods, .mixed])
    func workspaceModes(mode: DependencyMode) {
        let container = ProjectContainer(for: makeConfiguration(mode: mode))

        #expect(container == .workspace(fileName: "Bookshelf.xcworkspace"))
        #expect(container.xcodebuildFlag == "-workspace")
    }

    @Test("the build command follows the container", arguments: [
        (DependencyMode.disabled, "-project", "Bookshelf.xcodeproj"),
        (DependencyMode.cocoapods, "-workspace", "Bookshelf.xcworkspace")
    ])
    func buildFollowsTheContainer(mode: DependencyMode, flag: String, fileName: String) throws {
        let runner = FakeProcessRunner()

        try BuildValidator(processRunner: runner)
            .validate(makeConfiguration(mode: mode), at: URL(fileURLWithPath: "/tmp/Bookshelf"))

        let arguments = try #require(runner.invocations.first).arguments
        let flagIndex = try #require(arguments.firstIndex(of: flag))
        #expect(arguments[arguments.index(after: flagIndex)] == fileName)
        #expect(!arguments.contains(flag == "-project" ? "-workspace" : "-project"))
    }

    @Test("open follows the container", arguments: [
        (DependencyMode.disabled, "/tmp/Bookshelf/Bookshelf.xcodeproj"),
        (DependencyMode.mixed, "/tmp/Bookshelf/Bookshelf.xcworkspace")
    ])
    func openFollowsTheContainer(mode: DependencyMode, path: String) throws {
        let runner = FakeProcessRunner()

        try ProjectOpener(processRunner: runner)
            .open(makeConfiguration(mode: mode), at: URL(fileURLWithPath: "/tmp/Bookshelf"))

        #expect(try #require(runner.invocations.first).arguments == [path])
    }
}
