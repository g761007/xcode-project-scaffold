@testable import ScaffoldCore
import ScaffoldSchema
import Testing

private let planner = GenerationPlanBuilder()

/// The architecture example (ADR-0004): for a pattern that ships one and a
/// project that keeps it, the example's sources replace the variant's default
/// screen. `minimal`, and any project that opts out, is untouched — the plain
/// UIKit/SwiftUI file lists in `GenerationPlanBuilderTests` still hold because
/// `validBaseline` is minimal.
@Suite("The architecture example")
struct ArchitectureExampleTests {
    static let mvvmUIKit = ProjectConfiguration.validBaseline.with {
        $0.architecture = .init(pattern: .mvvm, includeExample: true)
    }

    static let mvvmSwiftUI = ProjectConfiguration.validBaseline.with {
        $0.interface = .init(primary: .swiftUI)
        $0.architecture = .init(pattern: .mvvm, includeExample: true)
    }

    @Test("a UIKit MVVM project replaces the screen and adds a view model")
    func uiKitFileList() throws {
        let plan = try planner.makePlan(for: Self.mvvmUIKit)

        #expect(plan.files.map(\.path) == [
            ".gitignore",
            ".swiftformat",
            ".swiftlint.yml",
            "App/AppDelegate.swift",
            "App/GreetingViewModel.swift",
            "App/RootViewController.swift",
            "App/SceneDelegate.swift",
            "Makefile",
            "README.md",
            "Resources/Assets.xcassets/AccentColor.colorset/Contents.json",
            "Resources/Assets.xcassets/AppIcon.appiconset/Contents.json",
            "Resources/Assets.xcassets/Contents.json",
            "Tests/GreetingViewModelTests.swift",
            "Tests/RootViewControllerTests.swift",
            "project.yml",
            "scaffold.yml"
        ])
    }

    @Test("the UIKit view is driven by the view model, injected at the scene")
    func uiKitReplacesTheScreen() throws {
        let plan = try planner.makePlan(for: Self.mvvmUIKit)

        let view = try #require(plan.files.first { $0.path == "App/RootViewController.swift" })
        #expect(view.contents.contains("viewModel: GreetingViewModel"))

        let scene = try #require(plan.files.first { $0.path == "App/SceneDelegate.swift" })
        #expect(scene.contents.contains("RootViewController(viewModel:"))
    }

    @Test("a SwiftUI MVVM project replaces the view and adds a view model")
    func swiftUIFileList() throws {
        let plan = try planner.makePlan(for: Self.mvvmSwiftUI)

        #expect(plan.files.map(\.path) == [
            ".gitignore",
            ".swiftformat",
            ".swiftlint.yml",
            "App/ContentView.swift",
            "App/GreetingViewModel.swift",
            "App/MyAppApp.swift",
            "Makefile",
            "README.md",
            "Resources/Assets.xcassets/AccentColor.colorset/Contents.json",
            "Resources/Assets.xcassets/AppIcon.appiconset/Contents.json",
            "Resources/Assets.xcassets/Contents.json",
            "Tests/ContentViewTests.swift",
            "Tests/GreetingViewModelTests.swift",
            "project.yml",
            "scaffold.yml"
        ])
    }

    /// The SwiftUI view observes an `@Observable` view model — the same seam as
    /// UIKit's, reached through a different framework idiom (§3, ADR-0004).
    @Test("the SwiftUI view observes a view model")
    func swiftUIObservesViewModel() throws {
        let plan = try planner.makePlan(for: Self.mvvmSwiftUI)

        let view = try #require(plan.files.first { $0.path == "App/ContentView.swift" })
        #expect(view.contents.contains("viewModel: GreetingViewModel"))

        let model = try #require(plan.files.first { $0.path == "App/GreetingViewModel.swift" })
        #expect(model.contents.contains("@Observable"))
    }

    /// The example is sources only — a single app target, no change to the spec
    /// (ADR-0004), so project.yml must be byte-identical to the plain variant's,
    /// for each interface.
    @Test("the example does not touch project.yml", arguments: [UIFramework.uiKit, .swiftUI])
    func projectYMLUnchanged(interface: UIFramework) throws {
        let plain = try planner.makePlan(for: .validBaseline.with { $0.interface = .init(primary: interface) })
        let example = try planner.makePlan(for: interface == .uiKit ? Self.mvvmUIKit : Self.mvvmSwiftUI)

        let plainYML = try #require(plain.files.first { $0.path == "project.yml" }).contents
        let exampleYML = try #require(example.files.first { $0.path == "project.yml" }).contents
        #expect(exampleYML == plainYML)
    }

    @Test("the MVVM note and its diagram reach the README", arguments: [Self.mvvmUIKit, Self.mvvmSwiftUI])
    func architectureInReadme(configuration: ProjectConfiguration) throws {
        let readme = try #require(planner.makePlan(for: configuration).files.first { $0.path == "README.md" })

        #expect(readme.contents.contains("**MVVM.**"))
        #expect(readme.contents.contains("```mermaid"))
    }

    @Test("neither example leaves a placeholder behind", arguments: [Self.mvvmUIKit, Self.mvvmSwiftUI])
    func noPlaceholders(configuration: ProjectConfiguration) throws {
        for file in try planner.makePlan(for: configuration).files {
            #expect(!file.contents.contains("{{"), "\(file.path)")
            #expect(!file.path.contains("{{"), "\(file.path)")
        }
    }

    /// Opting out drops every example source but keeps the pattern's README
    /// note — the plain variant screen stands in. M4 covers this path in full.
    @Test("with the example off, the plain screen and the note both remain")
    func exampleOff() throws {
        let plan = try planner.makePlan(for: .validBaseline.with {
            $0.architecture = .init(pattern: .mvvm, includeExample: false)
        })

        #expect(!plan.files.contains { $0.path == "App/GreetingViewModel.swift" })
        #expect(plan.files.contains { $0.path == "App/RootViewController.swift" })

        let readme = try #require(plan.files.first { $0.path == "README.md" })
        #expect(readme.contents.contains("**MVVM.**"))
    }
}
