@testable import ScaffoldCore
import ScaffoldSchema
import Testing

/// Plans the shipped templates plus whatever the test adds, so that a conflict
/// is provoked the way a real one would arrive: a layer claiming a path another
/// layer already owns. The shipped set has no conflicts of its own — the plan
/// contract tests pin that — so anything thrown here came from the addition.
private func plan(adding templates: [String: String]) throws -> GenerationPlan {
    let library = TemplateLibrary(templates: EmbeddedTemplates.all.merging(templates) { _, new in new })
    return try GenerationPlanBuilder(library: library).makePlan(
        for: .validBaseline,
        options: GenerationOptions(initializeGit: false, runGenerator: false)
    )
}

private let secondAppDelegate = ["Shared/App/AppDelegate.swift": "// a second app delegate\n"]

/// Issue #95, roadmap §13.4: the manifest is built in full before anything is
/// written, so one path claimed twice is a reported failure rather than a race
/// whichever was added last wins.
@Suite("One path claimed twice")
struct TemplateConflictTests {
    /// The roadmap's own example, in the layers this version actually has:
    /// `Shared` and the variant both believing they own the app delegate.
    @Test("a shared file landing on a variant's path is a conflict")
    func peerLayers() throws {
        let error = #expect(throws: TemplateConflictError.self) {
            try plan(adding: secondAppDelegate)
        }

        #expect(try #require(error).path == "App/AppDelegate.swift")
        #expect(try #require(error).origins == ["Shared", "Variants/ios-uikit"])
    }

    /// Naming only the path would send a reader searching a template tree for
    /// which two layers to look at; naming only the layers would not say which
    /// of their files collided.
    @Test("the report names the code, the path and both origins")
    func report() throws {
        let error = #expect(throws: TemplateConflictError.self) {
            try plan(adding: secondAppDelegate)
        }

        #expect(try #require(error).description == """
        TEMPLATE_CONFLICT: the same file is claimed twice.
        File:
          App/AppDelegate.swift
        Claimed by:
          Shared
          Variants/ios-uikit
        """)
    }

    /// Templates are not the only thing a run writes. A template landing on
    /// `project.yml` would overwrite the spec — or be overwritten by it —
    /// depending on nothing more than the order the plan appends in.
    @Test("a template landing on a rendered file's path is a conflict too")
    func templateAgainstRenderer() throws {
        let error = #expect(throws: TemplateConflictError.self) {
            try plan(adding: ["Shared/project.yml": "# not the generated one\n"])
        }

        #expect(try #require(error).path == "project.yml")
        #expect(try #require(error).origins == ["Shared", "XcodeGenSpecEncoder"])
    }

    /// Where a file lands is decided by rendering, not by the template's own
    /// spelling: these two paths differ until `{{PROJECT_NAME}}` has a value.
    /// Checking before rendering would call the pair distinct and let one
    /// silently overwrite the other.
    @Test("two templates that render to one path conflict")
    func afterRendering() throws {
        let error = #expect(throws: TemplateConflictError.self) {
            try plan(adding: [
                "Shared/{{PROJECT_NAME}}Notes.md": "# from the shared layer\n",
                "Variants/ios-uikit/MyAppNotes.md": "# from the variant\n"
            ])
        }

        #expect(try #require(error).path == "MyAppNotes.md")
        #expect(try #require(error).origins == ["Shared", "Variants/ios-uikit"])
    }

    /// A conflict is a fault in the templates, fixed one at a time, so the
    /// report names one — and always the same one, though a template set is a
    /// dictionary and reaches the manifest in no particular order.
    @Test("the same template set always reports the same conflict")
    func deterministic() throws {
        for _ in 1 ... 5 {
            let error = #expect(throws: TemplateConflictError.self) {
                try plan(adding: secondAppDelegate.merging(
                    ["Shared/App/SceneDelegate.swift": "// a second scene delegate\n"]
                ) { _, new in new })
            }

            #expect(try #require(error).path == "App/AppDelegate.swift")
        }
    }
}

/// The overlay replaces the variant's screen by declaration (ADR-0004). It is
/// the one case where two layers name one path on purpose, and the conflict
/// check must not mistake it for the accident it was built to catch.
@Suite("What is allowed to claim a path twice")
struct OverlayIsNotAConflictTests {
    static let examples: [ProjectConfiguration] = [
        ArchitectureExampleTests.mvvmUIKit,
        ArchitectureExampleTests.mvvmSwiftUI,
        ArchitectureExampleTests.mvvmMacOSSwiftUI,
        ArchitectureExampleTests.mvvmMacOSAppKit,
        ArchitectureExampleTests.mvvmcUIKit
    ]

    /// Every pattern × variant that ships an example, including MVVM-C's, whose
    /// overlay also removes a variant file rather than replacing it.
    @Test("every example plans without conflict", arguments: examples)
    func examplesPlan(configuration: ProjectConfiguration) throws {
        let plan = try GenerationPlanBuilder().makePlan(for: configuration)

        #expect(Set(plan.files.map(\.path)).count == plan.files.count)
    }

    /// The replacement itself, not merely the absence of a throw: the path the
    /// variant owns carries the example's file afterwards.
    @Test("the example's file is the one that survives at the shared path")
    func exampleWins() throws {
        let plan = try GenerationPlanBuilder().makePlan(for: ArchitectureExampleTests.mvvmUIKit)
        let screen = try #require(plan.files.first { $0.path == "App/RootViewController.swift" })

        #expect(screen.contents.contains("GreetingViewModel"))
    }

    /// Every origin at once — both extensions, CI, localization, environment
    /// values, secrets and Bundler — because a manifest that covers everything
    /// has to be right about everything, and a false conflict here would refuse
    /// a project that is perfectly legal.
    @Test("a project using every origin plans without conflict")
    func everythingAtOnce() throws {
        let plan = try GenerationPlanBuilder().makePlan(for: Self.everyOrigin)

        #expect(Set(plan.files.map(\.path)).count == plan.files.count)
        for path in [
            "Gemfile",
            "Podfile",
            "project.yml",
            "scaffold.yml",
            "App/AppCoordinator.swift",
            "Configurations/Secrets.example.xcconfig",
            "Resources/zh-Hant.lproj/Localizable.strings",
            "UITests/SmokeTests.swift",
            "Widget/BookshelfWidget.swift",
            "NotificationService/NotificationService.swift",
            ".github/workflows/build.yml"
        ] {
            #expect(plan.files.contains { $0.path == path }, "\(path) is missing from the plan")
        }
    }

    static let everyOrigin = ProjectConfiguration(
        project: .init(name: "Bookshelf", bundleIdentifier: "com.example.bookshelf"),
        interface: .init(primary: .uiKit),
        architecture: .init(pattern: .mvvmCoordinator, includeExample: true),
        dependencyManagement: .init(mode: .cocoapods, cocoapods: .init(
            pods: [Pod(name: "SnapKit", source: .version("5.7.1"))],
            bundler: .init(enabled: true, cocoapodsVersion: "1.16.2")
        )),
        environments: [
            Environment(name: "development", configuration: "Debug", values: ["API_BASE_URL": "https://dev.example.com"]),
            Environment(name: "production", configuration: "Release")
        ],
        secrets: Secrets(keys: [.init(name: "API_KEY", example: "example-123")]),
        localization: .init(languages: ["en", "zh-Hant"]),
        testing: .init(ui: .init(enabled: true)),
        ci: .init(),
        extensions: .init(widget: .init(), notificationService: .init())
    )
}
