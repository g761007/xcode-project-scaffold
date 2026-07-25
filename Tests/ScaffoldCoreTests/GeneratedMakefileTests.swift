@testable import ScaffoldCore
import ScaffoldSchema
import Testing

private let planner = GenerationPlanBuilder()

/// The `Makefile` a generated project ships is the first thing anyone runs in
/// it, and for three versions it was wrong in three ways — each of them a
/// constant where a rendered value belonged. §7.3 keeps conditionals out of
/// templates precisely so that structural differences arrive as values; these
/// pin the values.
@Suite("The generated Makefile")
struct GeneratedMakefileTests {
    /// The generated Makefile is the first thing anyone runs in a new project,
    /// and it had three constants in it that the configuration already knew:
    /// a device name that stops existing when Xcode moves on, an iOS
    /// destination handed to macOS projects, and the `.xcodeproj` handed to
    /// projects whose pods live in a workspace. All three are values now.
    @Test("the build destination needs no device on either platform", arguments: [
        (ApplePlatform.iOS, "generic/platform=iOS Simulator"),
        (.macOS, "platform=macOS")
    ])
    func buildDestination(platform: ApplePlatform, expected: String) throws {
        let makefile = try makefile(for: .validBaseline.with {
            $0.product.platform = platform
            $0.interface = .init(primary: platform == .iOS ? .uiKit : .appKit)
        })

        #expect(makefile.contains("BUILD_DESTINATION ?= \(expected)"))
    }

    /// A device name written into a generated project stops existing a year
    /// later. iOS resolves one when `make test` runs; macOS needs none.
    @Test("no Makefile names a simulator", arguments: [ApplePlatform.iOS, .macOS])
    func noHardcodedDevice(platform: ApplePlatform) throws {
        let makefile = try makefile(for: .validBaseline.with {
            $0.product.platform = platform
            $0.interface = .init(primary: platform == .iOS ? .uiKit : .appKit)
        })

        #expect(!makefile.contains("name=iPhone"))
        if platform == .macOS {
            #expect(!makefile.contains("iOS Simulator"))
        }
    }

    /// The one rule `ProjectContainer` exists to state once. A Makefile that
    /// answered it separately would build a CocoaPods project without its pods.
    @Test("the Makefile drives the container the rest of the tool drives", arguments: [
        (DependencyMode.disabled, "-project", "MyApp.xcodeproj"),
        (.spm, "-project", "MyApp.xcodeproj"),
        (.cocoapods, "-workspace", "MyApp.xcworkspace"),
        (.mixed, "-workspace", "MyApp.xcworkspace")
    ])
    func makefileContainer(mode: DependencyMode, flag: String, fileName: String) throws {
        let makefile = try makefile(for: .validBaseline.with { $0.dependencyManagement.mode = mode })

        #expect(makefile.contains("CONTAINER := \(fileName)"))
        #expect(makefile.contains("CONTAINER_FLAG := \(flag)"))
        #expect(!makefile.contains("-project $(PROJECT).xcodeproj"))
    }

    /// Regenerating the project file de-integrates the pods, so `make generate`
    /// has to install them again — and the sequence has to be the one
    /// generation itself performs, not a second telling of it.
    @Test("make generate reinstalls pods, through Bundler when it is used")
    func makefileGenerateRecipe() throws {
        let plain = try makefile(for: .validBaseline)
        #expect(plain.contains("\txcodegen generate"))
        // Tab-prefixed: the comment above the container variable mentions the
        // command, and a recipe line is the only place it would run.
        #expect(!plain.contains("\tpod install"))

        let pods = try makefile(for: .validBaseline.with {
            $0.dependencyManagement.mode = .cocoapods
        })
        #expect(pods.contains("\txcodegen generate\n\tpod install"))

        let bundled = try makefile(for: .validBaseline.with {
            $0.dependencyManagement.mode = .cocoapods
            $0.dependencyManagement.cocoapods = .init(bundler: .init(enabled: true))
        })
        #expect(bundled.contains("\tbundle install\n\tbundle exec pod install"))
    }

    /// The README sits beside the Makefile and describes it. Left as constants,
    /// it told a macOS project it builds "for the simulator" and told a
    /// CocoaPods project to open the `.xcodeproj` the Makefile no longer
    /// touches.
    @Test("the README names the container the Makefile drives", arguments: [
        (DependencyMode.spm, "MyApp.xcodeproj"),
        (.cocoapods, "MyApp.xcworkspace")
    ])
    func readmeContainer(mode: DependencyMode, fileName: String) throws {
        let readme = try file("README.md", for: .validBaseline.with { $0.dependencyManagement.mode = mode })

        #expect(readme.contains("produce \(fileName)"))
        #expect(readme.contains("Open `\(fileName)`"))
    }

    @Test("the README says what make build builds for", arguments: [
        (ApplePlatform.iOS, "build for the simulator"),
        (.macOS, "build for macOS")
    ])
    func readmeBuildTarget(platform: ApplePlatform, expected: String) throws {
        let readme = try file("README.md", for: .validBaseline.with {
            $0.product.platform = platform
            $0.interface = .init(primary: platform == .iOS ? .uiKit : .appKit)
        })

        #expect(readme.contains(expected))
    }

    /// A project with no pods is not told to install CocoaPods, and one that
    /// runs the install through Bundler is told to install that too.
    @Test("the README's setup commands are the tools this project needs")
    func readmeSetupCommands() throws {
        let plain = try file("README.md", for: .validBaseline)
        #expect(plain.contains("brew install xcodegen"))
        #expect(!plain.contains("cocoapods"))
        #expect(!plain.contains("gem install bundler"))

        let pods = try file("README.md", for: .validBaseline.with {
            $0.dependencyManagement.mode = .cocoapods
            $0.dependencyManagement.cocoapods = .init(bundler: .init(enabled: true))
        })
        #expect(pods.contains("brew install xcodegen cocoapods"))
        #expect(pods.contains("gem install bundler"))
    }

    /// Removing the project file and leaving the workspace that points at it
    /// is worse than not cleaning: the next `open` finds a workspace whose
    /// project is gone.
    @Test("clean removes everything a run produces, and nothing else")
    func cleanArtefacts() throws {
        let plain = try makefile(for: .validBaseline)
        #expect(plain.contains("rm -rf DerivedData build MyApp.xcodeproj\n"))

        let pods = try makefile(for: .validBaseline.with { $0.dependencyManagement.mode = .cocoapods })
        #expect(pods.contains("rm -rf DerivedData build MyApp.xcodeproj MyApp.xcworkspace Pods"))
    }

    private func makefile(for configuration: ProjectConfiguration) throws -> String {
        try file("Makefile", for: configuration)
    }

    private func file(_ path: String, for configuration: ProjectConfiguration) throws -> String {
        let plan = try planner.makePlan(for: configuration)
        return try #require(plan.files.first { $0.path == path }).contents
    }
}
