@testable import ScaffoldCore
import ScaffoldSchema
import Testing

private let planner = GenerationPlanBuilder()

/// The file list is the contract §12.1 asks these tests to pin: it is what a
/// user sees after `init`, and dropping a file from it is a silent regression
/// that a build check would not necessarily catch.
@Suite("What a run would create")
struct GenerationPlanContractTests {
    @Test("a UIKit project")
    func uiKitFileList() throws {
        let plan = try planner.makePlan(for: .validBaseline)

        #expect(plan.files.map(\.path) == [
            ".gitignore",
            ".swiftformat",
            ".swiftlint.yml",
            "App/AppDelegate.swift",
            "App/RootViewController.swift",
            "App/SceneDelegate.swift",
            "Makefile",
            "README.md",
            "Resources/Assets.xcassets/AccentColor.colorset/Contents.json",
            "Resources/Assets.xcassets/AppIcon.appiconset/Contents.json",
            "Resources/Assets.xcassets/Contents.json",
            "Tests/RootViewControllerTests.swift",
            "project.yml",
            "scaffold.yml"
        ])
    }

    @Test("a SwiftUI project differs only in its sources")
    func swiftUIFileList() throws {
        let plan = try planner.makePlan(for: .validBaseline.with {
            $0.interface = .init(primary: .swiftUI)
        })

        #expect(plan.files.map(\.path) == [
            ".gitignore",
            ".swiftformat",
            ".swiftlint.yml",
            "App/ContentView.swift",
            "App/MyAppApp.swift",
            "Makefile",
            "README.md",
            "Resources/Assets.xcassets/AccentColor.colorset/Contents.json",
            "Resources/Assets.xcassets/AppIcon.appiconset/Contents.json",
            "Resources/Assets.xcassets/Contents.json",
            "Tests/ContentViewTests.swift",
            "project.yml",
            "scaffold.yml"
        ])
    }

    /// macOS SwiftUI shares the SwiftUI variant's file shape — the sources are
    /// cross-platform for this content — differing only in the AppIcon it now
    /// carries (M2 moved that to the variant layer). The build/test proof is the
    /// E2E job; this pins the list.
    @Test("a macOS SwiftUI project has the SwiftUI file shape")
    func macOSSwiftUIFileList() throws {
        let plan = try planner.makePlan(for: .validBaseline.with {
            $0.product.platform = .macOS
            $0.interface = .init(primary: .swiftUI)
        })

        #expect(plan.files.map(\.path) == [
            ".gitignore",
            ".swiftformat",
            ".swiftlint.yml",
            "App/ContentView.swift",
            "App/MyAppApp.swift",
            "Makefile",
            "README.md",
            "Resources/Assets.xcassets/AccentColor.colorset/Contents.json",
            "Resources/Assets.xcassets/AppIcon.appiconset/Contents.json",
            "Resources/Assets.xcassets/Contents.json",
            "Tests/ContentViewTests.swift",
            "project.yml",
            "scaffold.yml"
        ])
    }

    /// The assertion §12.1 asks for: a placeholder that survived into a
    /// generated file would often still compile, so nothing else would catch it.
    /// Covers macOS as well, since a new variant reaches the substitution afresh.
    @Test("no file contains an unsubstituted placeholder", arguments: [
        ProjectConfiguration.validBaseline,
        .validBaseline.with { $0.interface = .init(primary: .swiftUI) },
        .validBaseline.with {
            $0.product.platform = .macOS
            $0.interface = .init(primary: .swiftUI)
        }
    ])
    func noPlaceholdersSurvive(configuration: ProjectConfiguration) throws {
        let plan = try planner.makePlan(for: configuration.with { $0.project.name = "Bookshelf" })

        for file in plan.files {
            #expect(!file.contents.contains("{{"), "\(file.path)")
            #expect(!file.path.contains("{{"), "\(file.path)")
        }
    }

    @Test("the project name reaches the sources")
    func projectNameIsSubstituted() throws {
        let plan = try planner.makePlan(for: .validBaseline.with { $0.project.name = "Bookshelf" })

        let tests = try #require(plan.files.first { $0.path == "Tests/RootViewControllerTests.swift" })
        #expect(tests.contents.contains("@testable import Bookshelf"))
    }

    /// The SwiftUI variant names a file after the project, so the placeholder
    /// has to be substituted in paths as well as in contents.
    @Test("a placeholder in a filename is substituted")
    func filenamePlaceholder() throws {
        let plan = try planner.makePlan(for: .validBaseline.with {
            $0.project.name = "Bookshelf"
            $0.interface = .init(primary: .swiftUI)
        })

        #expect(plan.files.contains { $0.path == "App/BookshelfApp.swift" })
    }

    @Test("the architecture description reaches the README")
    func architectureDescription() throws {
        let plan = try planner.makePlan(for: .validBaseline)

        let readme = try #require(plan.files.first { $0.path == "README.md" })
        #expect(readme.contents.contains("**Minimal.**"))
    }

    @Test("planning is deterministic")
    func deterministic() throws {
        #expect(try planner.makePlan(for: .validBaseline) == planner.makePlan(for: .validBaseline))
    }
}

/// M4 already omits the test target when unit testing is off, and omits nothing
/// for the quality switches. If the file list ignored them too, a project would
/// get a `Tests/` directory nothing compiles and a `.swiftlint.yml` it asked
/// not to have.
@Suite("Switches in the configuration change the file list")
struct GenerationPlanSwitchTests {
    @Test("turning off unit testing removes the test sources")
    func withoutTests() throws {
        let plan = try planner.makePlan(for: .validBaseline.with { $0.testing.unit = .disabled })

        #expect(!plan.files.contains { $0.path.hasPrefix("Tests/") })
    }

    @Test("turning off a linter removes its configuration file")
    func withoutLinters() throws {
        let plan = try planner.makePlan(for: .validBaseline.with {
            $0.quality.swiftlint = false
            $0.quality.swiftformat = false
        })

        #expect(!plan.files.contains { $0.path == ".swiftlint.yml" })
        #expect(!plan.files.contains { $0.path == ".swiftformat" })
    }

    @Test("each linter can be turned off on its own")
    func oneLinterOnly() throws {
        let plan = try planner.makePlan(for: .validBaseline.with { $0.quality.swiftlint = false })

        #expect(!plan.files.contains { $0.path == ".swiftlint.yml" })
        #expect(plan.files.contains { $0.path == ".swiftformat" })
    }

    /// The Makefile always has a `lint` target; what it runs is decided in
    /// Swift and arrives as a value, because §7.3 keeps conditionals out of
    /// templates.
    @Test("the Makefile runs only the linters that are enabled")
    func makefileLintRecipe() throws {
        let enabled = try planner.makePlan(for: .validBaseline)
        let makefile = try #require(enabled.files.first { $0.path == "Makefile" })
        #expect(makefile.contents.contains("\tswiftformat --lint ."))
        #expect(makefile.contents.contains("\tswiftlint --strict"))

        let disabled = try planner.makePlan(for: .validBaseline.with {
            $0.quality.swiftlint = false
            $0.quality.swiftformat = false
        })
        let bare = try #require(disabled.files.first { $0.path == "Makefile" })
        #expect(!bare.contents.contains("swiftlint"))
        #expect(bare.contents.contains("No linters are enabled"))
    }

    /// With environments, the Makefile has to name the scheme that actually
    /// exists — §9's rule gives it the bare project name only when an
    /// environment builds Release.
    @Test("the Makefile names a scheme the project really has")
    func makefileSchemeName() throws {
        let plan = try planner.makePlan(for: .validBaseline.with {
            $0.environments = [
                Environment(name: "development", configuration: "Debug"),
                Environment(name: "production", configuration: "Release")
            ]
        })

        let makefile = try #require(plan.files.first { $0.path == "Makefile" })
        let projectYML = try #require(plan.files.first { $0.path == "project.yml" })

        #expect(makefile.contents.contains("SCHEME  := MyApp\n"))
        #expect(projectYML.contents.contains("  MyApp:\n    build:"))
    }

    @Test("with no Release environment the Makefile names a suffixed scheme")
    func makefileSuffixedSchemeName() throws {
        let plan = try planner.makePlan(for: .validBaseline.with {
            $0.environments = [Environment(name: "alpha", configuration: "Alpha")]
        })

        let makefile = try #require(plan.files.first { $0.path == "Makefile" })
        #expect(makefile.contents.contains("SCHEME  := MyApp-Alpha"))
    }
}

@Suite("What a run would execute")
struct GenerationPlanCommandTests {
    @Test("git comes first, then the generator")
    func defaultCommands() throws {
        let commands = try planner.makePlan(for: .validBaseline).commands

        #expect(commands.map(\.executable) == ["git", "git", "git", "xcodegen"])
        #expect(commands.first?.arguments == ["init", "--initial-branch", "main"])
        #expect(commands.last?.arguments == ["generate"])
    }

    @Test("the initial branch follows the configuration")
    func branchName() throws {
        let plan = try planner.makePlan(for: .validBaseline.with { $0.git.defaultBranch = "trunk" })

        #expect(plan.commands.first?.arguments.contains("trunk") == true)
    }

    @Test("skipping git leaves only the generator")
    func withoutGit() throws {
        let plan = try planner.makePlan(
            for: .validBaseline,
            options: GenerationOptions(initializeGit: false)
        )

        #expect(plan.commands.map(\.executable) == ["xcodegen"])
    }

    @Test("skipping the generator leaves only git")
    func withoutGenerator() throws {
        let plan = try planner.makePlan(
            for: .validBaseline,
            options: GenerationOptions(runGenerator: false)
        )

        #expect(plan.commands.allSatisfy { $0.executable == "git" })
    }

    /// Every command is explained, because the plan is read by people deciding
    /// whether to let it run.
    @Test("every command says what it is for")
    func commandsArePurposeful() throws {
        for command in try planner.makePlan(for: .validBaseline).commands {
            #expect(!command.purpose.isEmpty)
        }
    }
}

@Suite("Templates that do not exist")
struct TemplateSelectionTests {
    /// macOS AppKit passes validation now but has no templates until M4, so a
    /// plan for it is a template lookup that finds nothing. Failing with a clear
    /// message beats producing a project with no sources in it.
    @Test("a variant with no templates is an error")
    func unknownVariant() throws {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.product.platform = .macOS
            $0.interface = .init(primary: .appKit)
        }

        #expect(throws: TemplateNotFoundError.self) {
            try planner.makePlan(for: configuration)
        }
    }

    @Test("an architecture with no description is an error")
    func unknownArchitecture() throws {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.architecture.pattern = .clean
        }

        #expect(throws: TemplateNotFoundError.self) {
            try planner.makePlan(for: configuration)
        }
    }
}
