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

    static let mvvmcUIKit = ProjectConfiguration.validBaseline.with {
        $0.architecture = .init(pattern: .mvvmCoordinator, includeExample: true)
    }

    /// One pattern/interface asked for with `includeExample: false`, and the
    /// README note that should stand in for the example it declined.
    struct OffCase: Sendable, CustomStringConvertible {
        let interface: UIFramework
        let pattern: ArchitecturePattern
        let note: String

        var description: String {
            "\(pattern.rawValue)-\(interface.rawValue)"
        }
    }

    static let offCases: [OffCase] = [
        OffCase(interface: .uiKit, pattern: .mvvm, note: "**MVVM.**"),
        OffCase(interface: .swiftUI, pattern: .mvvm, note: "**MVVM.**"),
        OffCase(interface: .uiKit, pattern: .mvvmCoordinator, note: "**MVVM-C.**")
    ]

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

    @Test("no example leaves a placeholder behind", arguments: [Self.mvvmUIKit, Self.mvvmSwiftUI, Self.mvvmcUIKit])
    func noPlaceholders(configuration: ProjectConfiguration) throws {
        for file in try planner.makePlan(for: configuration).files {
            #expect(!file.contents.contains("{{"), "\(file.path)")
            #expect(!file.path.contains("{{"), "\(file.path)")
        }
    }

    @Test("a UIKit MVVM-C project is a coordinator with a list and a detail screen")
    func mvvmcFileList() throws {
        let plan = try planner.makePlan(for: Self.mvvmcUIKit)

        #expect(plan.files.map(\.path) == [
            ".gitignore",
            ".swiftformat",
            ".swiftlint.yml",
            "App/AppCoordinator.swift",
            "App/AppDelegate.swift",
            "App/ItemDetailViewController.swift",
            "App/ItemDetailViewModel.swift",
            "App/ItemListViewController.swift",
            "App/ItemListViewModel.swift",
            "App/SceneDelegate.swift",
            "Makefile",
            "README.md",
            "Resources/Assets.xcassets/AccentColor.colorset/Contents.json",
            "Resources/Assets.xcassets/AppIcon.appiconset/Contents.json",
            "Resources/Assets.xcassets/Contents.json",
            "Tests/ItemDetailViewModelTests.swift",
            "Tests/ItemListViewModelTests.swift",
            "project.yml",
            "scaffold.yml"
        ])
    }

    /// The coordinator supersedes the variant's single root screen; the
    /// `.removed` marker drops it and its test rather than leaving dead code.
    @Test("the plain root screen is removed and navigation runs through the coordinator")
    func mvvmcRemovesRootScreen() throws {
        let plan = try planner.makePlan(for: Self.mvvmcUIKit)
        let paths = plan.files.map(\.path)

        #expect(!paths.contains("App/RootViewController.swift"))
        #expect(!paths.contains("Tests/RootViewControllerTests.swift"))
        #expect(paths.contains("App/AppCoordinator.swift"))

        let scene = try #require(plan.files.first { $0.path == "App/SceneDelegate.swift" })
        #expect(scene.contents.contains("AppCoordinator"))
    }

    @Test("the MVVM-C example does not touch project.yml")
    func mvvmcProjectYMLUnchanged() throws {
        let plain = try planner.makePlan(for: .validBaseline)
        let example = try planner.makePlan(for: Self.mvvmcUIKit)

        let plainYML = try #require(plain.files.first { $0.path == "project.yml" }).contents
        let exampleYML = try #require(example.files.first { $0.path == "project.yml" }).contents
        #expect(exampleYML == plainYML)
    }

    @Test("the MVVM-C note and its diagram reach the README")
    func mvvmcArchitectureInReadme() throws {
        let readme = try #require(planner.makePlan(for: Self.mvvmcUIKit).files.first { $0.path == "README.md" })

        #expect(readme.contents.contains("**MVVM-C.**"))
        #expect(readme.contents.contains("```mermaid"))
        #expect(readme.contents.contains("Coordinator"))
    }

    /// Opting out (`includeExample: false`) drops every example source: the file
    /// list becomes the plain variant's exactly — no example files, and no empty
    /// pattern folders, because the overlay contributes nothing. The README keeps
    /// the pattern's note and diagram, now a guide to the structure the example
    /// would have built (§3.3–3.4). The on-path examples above prove the rest.
    @Test("with the example off, a project is the plain variant plus the pattern's note",
          arguments: Self.offCases)
    func exampleOff(offCase: OffCase) throws {
        let off = try planner.makePlan(for: .validBaseline.with {
            $0.interface = .init(primary: offCase.interface)
            $0.architecture = .init(pattern: offCase.pattern, includeExample: false)
        })
        let plain = try planner.makePlan(for: .validBaseline.with {
            $0.interface = .init(primary: offCase.interface)
        })

        // Exactly the plain variant's files — no example sources, and no folder
        // left empty by an overlay that contributed nothing.
        #expect(off.files.map(\.path) == plain.files.map(\.path))

        // ...but the README still documents the intended architecture as a guide.
        let readme = try #require(off.files.first { $0.path == "README.md" })
        #expect(readme.contents.contains(offCase.note))
        #expect(readme.contents.contains("```mermaid"))

        // No unsubstituted placeholder survives the off path either.
        for file in off.files {
            #expect(!file.contents.contains("{{"), "\(file.path)")
        }
    }
}
