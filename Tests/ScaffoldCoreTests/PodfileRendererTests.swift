import Foundation
@testable import ScaffoldCore
import ScaffoldSchema
import Testing

private func makeConfiguration(
    platform: ApplePlatform = .iOS,
    pods: [Pod]
) -> ProjectConfiguration {
    ProjectConfiguration(
        project: .init(name: "Bookshelf", bundleIdentifier: "com.example.bookshelf"),
        product: .init(platform: platform),
        interface: .init(primary: platform == .iOS ? .swiftUI : .appKit),
        dependencyManagement: .init(mode: .cocoapods, cocoapods: .init(pods: pods))
    )
}

/// Issue #63: the Podfile xscaffold writes — the five sources in CocoaPods'
/// own spelling, one line per subspec, everything on the app target.
@Suite("Rendering the Podfile")
struct PodfileRendererTests {
    let renderer = PodfileRenderer()

    @Test("the five sources render in Podfile spelling")
    func sources() {
        let podfile = renderer.render(makeConfiguration(pods: [
            Pod(name: "SnapKit", source: .version("5.7.0")),
            Pod(name: "Tagged", source: .gitTag(url: "https://example.com/t.git", tag: "v1")),
            Pod(name: "Branched", source: .gitBranch(url: "https://example.com/b.git", branch: "dev")),
            Pod(name: "Pinned", source: .gitCommit(url: "https://example.com/c.git", commit: "abc")),
            Pod(name: "Local", source: .path("../Local"))
        ]))

        #expect(podfile.contains("  pod 'SnapKit', '5.7.0'"))
        #expect(podfile.contains("  pod 'Tagged', :git => 'https://example.com/t.git', :tag => 'v1'"))
        #expect(podfile.contains("  pod 'Branched', :git => 'https://example.com/b.git', :branch => 'dev'"))
        #expect(podfile.contains("  pod 'Pinned', :git => 'https://example.com/c.git', :commit => 'abc'"))
        #expect(podfile.contains("  pod 'Local', :path => '../Local'"))
    }

    @Test("subspecs become one line each, sharing the source")
    func subspecs() {
        let podfile = renderer.render(makeConfiguration(pods: [
            Pod(name: "Firebase", source: .version("10.0.0"), subspecs: ["Auth", "Firestore"])
        ]))

        #expect(podfile.contains("  pod 'Firebase/Auth', '10.0.0'"))
        #expect(podfile.contains("  pod 'Firebase/Firestore', '10.0.0'"))
        #expect(!podfile.contains("pod 'Firebase',"))
    }

    @Test("the platform line follows the configuration", arguments: [
        (ApplePlatform.iOS, "platform :ios, '18.0'"),
        (.macOS, "platform :macos, '15.0'")
    ])
    func platformLine(platform: ApplePlatform, expected: String) {
        let podfile = renderer.render(makeConfiguration(platform: platform, pods: []))

        #expect(podfile.contains(expected))
    }

    @Test("pods live in the app target block, with frameworks on")
    func targetBlock() {
        let podfile = renderer.render(makeConfiguration(pods: [
            Pod(name: "SnapKit", source: .version("5.7.0"))
        ]))

        let lines = podfile.split(separator: "\n").map(String.init)
        let target = try? #require(lines.firstIndex(of: "target 'Bookshelf' do"))
        let frameworks = try? #require(lines.firstIndex(of: "  use_frameworks!"))
        let pod = try? #require(lines.firstIndex(of: "  pod 'SnapKit', '5.7.0'"))
        let end = try? #require(lines.lastIndex(of: "end"))
        #expect(target != nil && frameworks != nil && pod != nil && end != nil)
        if let target, let frameworks, let pod, let end {
            #expect(target < frameworks && frameworks < pod && pod < end)
        }
    }
}

/// The plan around the Podfile: the file, the command, and their absence.
@Suite("Pods in the plan")
struct PodsInThePlanTests {
    private func makePlan(
        _ configuration: ProjectConfiguration,
        options: GenerationOptions = GenerationOptions(initializeGit: true, runGenerator: true)
    ) throws -> GenerationPlan {
        guard case let .valid(validated, _) = ConfigurationValidator().check(configuration) else {
            struct DidNotValidate: Error {}
            throw DidNotValidate()
        }
        return try GenerationPlanBuilder().makePlan(for: validated, options: options)
    }

    private let cocoapods = makeConfiguration(pods: [Pod(name: "SnapKit", source: .version("5.7.0"))])

    @Test("cocoapods mode plans the Podfile and pod install after the generator")
    func podfileAndInstall() throws {
        let plan = try makePlan(cocoapods)

        #expect(plan.files.contains { $0.path == "Podfile" })
        let executables = plan.commands.map(\.executable)
        let generator = try #require(executables.firstIndex(of: "xcodegen"))
        let pod = try #require(executables.firstIndex(of: "pod"))
        #expect(generator < pod, "pods need the project file the generator produces")
    }

    @Test("skipping the generator skips pod install, but keeps the Podfile")
    func skipGenerateSkipsPods() throws {
        let plan = try makePlan(cocoapods, options: GenerationOptions(initializeGit: false, runGenerator: false))

        #expect(plan.files.contains { $0.path == "Podfile" })
        #expect(!plan.commands.map(\.executable).contains("pod"))
    }

    @Test("mode none plans neither")
    func noneModePlansNeither() throws {
        let plan = try makePlan(ProjectConfiguration(
            project: .init(name: "Bookshelf", bundleIdentifier: "com.example.bookshelf"),
            interface: .init(primary: .swiftUI)
        ))

        #expect(!plan.files.contains { $0.path == "Podfile" })
        #expect(!plan.commands.map(\.executable).contains("pod"))
    }
}

/// Issue #63: pod install can return success without the workspace it exists
/// to produce; the verification finds that now instead of xcodebuild later.
@Suite("Verifying the workspace was produced")
struct WorkspaceVerificationTests {
    private let plan = GenerationPlan(
        files: [],
        commands: [PlannedCommand(executable: "pod", arguments: ["install"], purpose: "Install pods")]
    )

    @Test("a missing workspace after pod install is a loud failure")
    func missingWorkspace() throws {
        try withTemporaryDirectory { root in
            let container = ProjectContainer(for: makeConfiguration(pods: []))

            #expect(throws: GenerationError.workspaceNotProduced("Bookshelf.xcworkspace")) {
                try container.verifyProduced(by: plan, at: root)
            }
        }
    }

    @Test("a present workspace passes")
    func presentWorkspace() throws {
        try withTemporaryDirectory { root in
            try FileManager.default.createDirectory(
                at: root.appendingPathComponent("Bookshelf.xcworkspace"),
                withIntermediateDirectories: true
            )

            try ProjectContainer(for: makeConfiguration(pods: [])).verifyProduced(by: plan, at: root)
        }
    }

    @Test("a plan that never ran pod install promises nothing")
    func noPodsNoPromise() throws {
        try withTemporaryDirectory { root in
            let bare = GenerationPlan(files: [], commands: [])

            try ProjectContainer(for: makeConfiguration(pods: [])).verifyProduced(by: bare, at: root)
        }
    }
}

private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("xscaffold-podfile-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try body(root)
}
