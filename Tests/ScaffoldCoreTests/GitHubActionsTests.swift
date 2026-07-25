@testable import ScaffoldCore
import ScaffoldSchema
import Testing
import Yams

/// Issue #80: the `ci` section and the GitHub Actions workflows it generates.
/// The steps must branch with the dependency mode and drive the container
/// `ProjectContainer` decides — a workflow building the bare project of a
/// CocoaPods app would pass generation and fail its first push.
@Suite("GitHub Actions workflows")
struct GitHubActionsTests {
    private func rendered(_ configuration: ProjectConfiguration) -> [PlannedFile] {
        GitHubActionsRenderer().files(for: configuration)
    }

    private func makeConfiguration(
        mode: DependencyMode = .disabled,
        bundler: Bool = false,
        workflows: ContinuousIntegration.Workflows? = nil
    ) -> ProjectConfiguration {
        .validBaseline.with {
            $0.ci = ContinuousIntegration(workflows: workflows)
            $0.dependencyManagement.mode = mode
            if mode == .cocoapods || mode == .mixed {
                $0.dependencyManagement.cocoapods = .init(
                    pods: [Pod(name: "SnapKit", source: .version("5.7.0"))],
                    bundler: bundler ? .init(enabled: true, cocoapodsVersion: "1.16.2") : nil
                )
            }
            if mode == .mixed {
                $0.dependencyManagement.spm = .init(packages: [SwiftPackage(
                    name: "Alamofire", url: "https://example.com/a.git",
                    requirement: .from("5.9.0"), products: []
                )])
            }
        }
    }

    @Test("an omitted ci section generates nothing")
    func omittedGeneratesNothing() {
        #expect(rendered(.validBaseline).isEmpty)
    }

    @Test("each switch is one file, and stating ci means all three")
    func switchesAreFiles() {
        let all = rendered(makeConfiguration()).map(\.path)
        #expect(all == [
            ".github/workflows/build.yml",
            ".github/workflows/test.yml",
            ".github/workflows/lint.yml"
        ])

        let testOnly = rendered(makeConfiguration(
            workflows: .init(build: false, lint: false)
        )).map(\.path)
        #expect(testOnly == [".github/workflows/test.yml"])
    }

    /// Syntax is guaranteed, not hoped for: every workflow this version can
    /// produce parses as YAML.
    @Test("every generated workflow parses as YAML", arguments: [
        DependencyMode.disabled, .spm, .cocoapods, .mixed
    ], [false, true])
    func workflowsParse(mode: DependencyMode, bundler: Bool) throws {
        for file in rendered(makeConfiguration(mode: mode, bundler: bundler)) {
            let document = try #require(try Yams.load(yaml: file.contents) as? [String: Any], "\(file.path)")
            #expect(document["jobs"] != nil, "\(file.path)")
        }
    }

    @Test("SPM resolves packages and installs no pods")
    func spmShape() throws {
        let build = try #require(rendered(makeConfiguration(mode: .spm)).first)

        #expect(build.contents.contains("run: xcodebuild -resolvePackageDependencies"))
        #expect(!build.contents.contains("pod install"))
    }

    @Test("bare CocoaPods installs pods; Bundler routes through bundle exec")
    func podShapes() throws {
        let bare = try #require(rendered(makeConfiguration(mode: .cocoapods)).first).contents
        #expect(bare.contains("run: pod install"))
        #expect(!bare.contains("bundle"))

        let bundled = try #require(rendered(makeConfiguration(mode: .cocoapods, bundler: true)).first).contents
        #expect(bundled.contains("run: bundle install"))
        #expect(bundled.contains("run: bundle exec pod install"))
        #expect(!bundled.contains("run: pod install"), "the bare install is replaced, not joined")
    }

    /// The container rule, once more at the CI boundary: pods build the
    /// workspace `pod install` produced, everything else the project file.
    @Test("build and test drive the container the mode decides")
    func containerFollowsMode() {
        let project = rendered(makeConfiguration(mode: .spm))
        for file in project.prefix(2) {
            #expect(file.contents.contains("-project 'MyApp.xcodeproj'"), "\(file.path)")
        }

        let workspace = rendered(makeConfiguration(mode: .cocoapods))
        for file in workspace.prefix(2) {
            #expect(file.contents.contains("-workspace 'MyApp.xcworkspace'"), "\(file.path)")
        }
    }

    @Test("the generator runs before the dependency install, which runs before the build")
    func stepOrder() throws {
        let build = try #require(rendered(makeConfiguration(mode: .cocoapods, bundler: true)).first).contents
        let lines = build.split(separator: "\n").map(String.init)

        let generate = try #require(lines.firstIndex { $0.contains("xcodegen generate") })
        let install = try #require(lines.firstIndex { $0.contains("bundle install") })
        let podInstall = try #require(lines.firstIndex { $0.contains("bundle exec pod install") })
        let xcodebuild = try #require(lines.firstIndex { $0.contains("xcodebuild build") })
        #expect(generate < install && install < podInstall && podInstall < xcodebuild)
    }

    @Test("lint installs only the enabled tools and runs the Makefile's recipe")
    func lintFollowsQuality() throws {
        func lintContents(_ configuration: ProjectConfiguration) throws -> String {
            let file = try #require(rendered(configuration).first { $0.path.hasSuffix("lint.yml") })
            return file.contents
        }

        let both = try lintContents(makeConfiguration())
        #expect(both.contains("run: brew install swiftformat swiftlint"))
        #expect(both.contains("run: make lint"))

        let lintOnly = try lintContents(makeConfiguration().with { $0.quality.swiftformat = false })
        #expect(lintOnly.contains("run: brew install swiftlint"))
        #expect(!lintOnly.contains("swiftformat"))

        let none = try lintContents(makeConfiguration().with {
            $0.quality = .init(swiftlint: false, swiftformat: false)
        })
        #expect(!none.contains("brew install"), "nothing to install still lints — the recipe says so")
        #expect(none.contains("run: make lint"))
    }

    @Test("the push trigger follows the configured default branch")
    func branchFollowsGit() throws {
        let workflow = try #require(rendered(.validBaseline.with {
            $0.ci = ContinuousIntegration()
            $0.git = .init(defaultBranch: "trunk")
        }).first)

        #expect(workflow.contents.contains("branches: [trunk]"))
    }
}

/// The wire format and the plan around the workflows.
@Suite("The ci section")
struct ContinuousIntegrationWireTests {
    let coder = ConfigurationCoder()

    @Test("ci decodes with its defaults, and omitted means none")
    func wireFormat() throws {
        let stated = try coder.decode("""
        project:
          name: App
          bundleIdentifier: com.example.app
        interface:
          primary: swiftui
        ci:
          provider: github-actions
          workflows:
            test: false
        """)
        #expect(stated.ci == ContinuousIntegration(
            provider: .gitHubActions,
            workflows: .init(build: true, test: false, lint: true)
        ))

        let bare = try coder.decode("""
        project:
          name: App
          bundleIdentifier: com.example.app
        interface:
          primary: swiftui
        ci: {}
        """)
        #expect(bare.ci == ContinuousIntegration())

        let omitted = try coder.decode("""
        project:
          name: App
          bundleIdentifier: com.example.app
        interface:
          primary: swiftui
        """)
        #expect(omitted.ci == nil)
    }

    @Test("the section round-trips, and an omitted one stays omitted")
    func roundTrips() throws {
        let stated = ProjectConfiguration.validBaseline.with {
            $0.ci = ContinuousIntegration(workflows: .init(lint: false))
        }
        let decoded = try coder.decode(coder.encode(stated))
        #expect(decoded.ci == stated.ci)

        let unstated = try coder.encode(.validBaseline)
        #expect(!unstated.contains("ci:"))
    }

    @Test("the plan carries the workflow files exactly when ci says so")
    func planCarriesWorkflows() throws {
        func planPaths(_ configuration: ProjectConfiguration) throws -> [String] {
            guard case let .valid(validated, _) = ConfigurationValidator().check(configuration) else {
                struct DidNotValidate: Error {}
                throw DidNotValidate()
            }
            return try GenerationPlanBuilder()
                .makePlan(for: validated, options: GenerationOptions(initializeGit: false, runGenerator: false))
                .files.map(\.path)
        }

        let with = try planPaths(.validBaseline.with { $0.ci = ContinuousIntegration() })
        #expect(with.contains(".github/workflows/build.yml"))
        #expect(with.contains(".github/workflows/test.yml"))
        #expect(with.contains(".github/workflows/lint.yml"))

        let without = try planPaths(.validBaseline)
        #expect(!without.contains { $0.hasPrefix(".github/") })
    }
}
