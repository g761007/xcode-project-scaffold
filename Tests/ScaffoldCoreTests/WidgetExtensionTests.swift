@testable import ScaffoldCore
import ScaffoldSchema
import Testing
import Yams

private func makeConfiguration(
    widget: AppExtensions.Widget? = nil,
    platform: ApplePlatform = .iOS,
    environments: [Environment] = []
) -> ProjectConfiguration {
    ProjectConfiguration(
        project: .init(name: "Bookshelf", bundleIdentifier: "com.example.bookshelf"),
        product: .init(platform: platform),
        interface: .init(primary: .swiftUI),
        environments: environments,
        extensions: widget.map { AppExtensions(widget: $0) }
    )
}

private func planFiles(_ configuration: ProjectConfiguration) throws -> [String] {
    guard case let .valid(validated, _) = ConfigurationValidator().check(configuration) else {
        struct DidNotValidate: Error {}
        throw DidNotValidate()
    }
    return try GenerationPlanBuilder()
        .makePlan(for: validated, options: GenerationOptions(initializeGit: false, runGenerator: false))
        .files.map(\.path)
}

/// Issue #81: `extensions.widget` — the wire format, the sources it plans, and
/// the app-extension target the project file grows. Omitted generates nothing.
@Suite("The widget extension in the configuration")
struct WidgetExtensionSchemaTests {
    let coder = ConfigurationCoder()

    @Test("naming the section is what asks for the widget")
    func namingItEnablesIt() throws {
        let decoded = try coder.decode("""
        project:
          name: App
          bundleIdentifier: com.example.app
        interface:
          primary: swiftui
        extensions:
          widget: {}
        """)

        #expect(decoded.extensions?.widget == AppExtensions.Widget())
        #expect(decoded.generatesWidget)
    }

    @Test("an omitted section generates nothing")
    func omittedIsOff() throws {
        let decoded = try coder.decode("""
        project:
          name: App
          bundleIdentifier: com.example.app
        interface:
          primary: swiftui
        """)

        #expect(decoded.extensions == nil)
        #expect(!decoded.generatesWidget)
    }

    /// The section can be parked without generating the target — which is the
    /// only reason `enabled` exists, given that naming the widget is already
    /// the request.
    @Test("an explicit false switches it off without removing the section")
    func explicitFalseIsOff() throws {
        let decoded = try coder.decode("""
        project:
          name: App
          bundleIdentifier: com.example.app
        interface:
          primary: swiftui
        extensions:
          widget:
            enabled: false
        """)

        #expect(decoded.extensions?.widget?.enabled == false)
        #expect(!decoded.generatesWidget)
    }

    /// `extensions:` naming no extension has to stay as empty as omitting it,
    /// or #82's notification service would arrive switched on for everyone who
    /// asked for a widget.
    @Test("an extensions section naming nothing generates nothing")
    func emptySectionIsOff() throws {
        let decoded = try coder.decode("""
        project:
          name: App
          bundleIdentifier: com.example.app
        interface:
          primary: swiftui
        extensions: {}
        """)

        #expect(decoded.extensions == AppExtensions())
        #expect(!decoded.generatesWidget)
    }

    @Test("the section round-trips")
    func roundTrips() throws {
        let configuration = makeConfiguration(widget: .init())

        let decoded = try coder.decode(coder.encode(configuration))

        #expect(decoded == configuration)
    }
}

@Suite("The widget extension in the plan")
struct WidgetExtensionPlanTests {
    @Test("enabled plans the bundle and the widget itself, named after the project")
    func enabledFiles() throws {
        let files = try planFiles(makeConfiguration(widget: .init()))

        #expect(files.contains("Widget/BookshelfWidgetBundle.swift"))
        #expect(files.contains("Widget/BookshelfWidget.swift"))
    }

    @Test("omitted plans no Widget directory at all")
    func omittedFiles() throws {
        let files = try planFiles(makeConfiguration())

        #expect(!files.contains { $0.hasPrefix("Widget/") })
    }

    /// XcodeGen writes the extension's Info.plist from `project.yml`, exactly
    /// as it does the app's, so the plan must not carry one of its own.
    @Test("the extension ships no Info.plist of its own")
    func noInfoPlist() throws {
        let files = try planFiles(makeConfiguration(widget: .init()))

        #expect(!files.contains("Widget/Info.plist"))
    }
}

@Suite("The widget extension in project.yml")
struct WidgetExtensionSpecTests {
    private func parse(_ configuration: ProjectConfiguration) throws -> [String: Any] {
        let yaml = try XcodeGenSpecEncoder().encode(XcodeGenSpecBuilder().makeSpec(for: configuration))
        return try #require(Yams.load(yaml: yaml) as? [String: Any])
    }

    private func targets(in configuration: ProjectConfiguration) throws -> [String: Any] {
        try #require(parse(configuration)["targets"] as? [String: Any])
    }

    @Test("enabled grows an app-extension target at the widgetkit extension point")
    func target() throws {
        let all = try targets(in: makeConfiguration(widget: .init()))

        let widget = try #require(all["BookshelfWidget"] as? [String: Any])

        #expect(widget["type"] as? String == "app-extension")
        #expect(widget["platform"] as? String == "iOS")
        #expect(widget["sources"] as? [String] == ["Widget"])

        let info = try #require(widget["info"] as? [String: Any])
        #expect(info["path"] as? String == "Widget/Info.plist")
        let properties = try #require(info["properties"] as? [String: Any])
        let extensionPoint = try #require(properties["NSExtension"] as? [String: Any])
        #expect(extensionPoint["NSExtensionPointIdentifier"] as? String == "com.apple.widgetkit-extension")
    }

    /// An extension whose bundle identifier is not prefixed by its container's
    /// cannot be installed, so the widget's is the app's plus `.widget`.
    @Test("the widget ships under the app's identity plus .widget")
    func identity() throws {
        let all = try targets(in: makeConfiguration(widget: .init()))

        let widget = try #require(all["BookshelfWidget"] as? [String: Any])
        let settings = try #require(widget["settings"] as? [String: Any])
        let base = try #require(settings["base"] as? [String: Any])
        #expect(base["PRODUCT_BUNDLE_IDENTIFIER"] as? String == "com.example.bookshelf.widget")
        #expect(base["PRODUCT_DISPLAY_NAME"] as? String == "Bookshelf Widget")
    }

    /// The same rule per environment: a project whose Debug build installs as
    /// `com.example.bookshelf.dev` needs its widget under that identifier too,
    /// not under the base one.
    @Test("each environment's identity reaches the widget as well as the app")
    func environmentIdentity() throws {
        let configuration = makeConfiguration(
            widget: .init(),
            environments: [
                Environment(
                    name: "development",
                    configuration: "Debug",
                    bundleIdentifierSuffix: ".dev",
                    displayNameSuffix: " Dev"
                ),
                Environment(name: "production", configuration: "Release")
            ]
        )

        let all = try targets(in: configuration)

        let widget = try #require(all["BookshelfWidget"] as? [String: Any])
        let settings = try #require(widget["settings"] as? [String: Any])
        let configs = try #require(settings["configs"] as? [String: Any])
        let debug = try #require(configs["Debug"] as? [String: Any])
        #expect(debug["PRODUCT_BUNDLE_IDENTIFIER"] as? String == "com.example.bookshelf.dev.widget")
        #expect(debug["PRODUCT_DISPLAY_NAME"] as? String == "Bookshelf Dev Widget")
        #expect(configs["Release"] == nil, "an environment that changes nothing needs no override")
    }

    /// Without the embed the extension is built and then left out of the app
    /// bundle, which fails at run time rather than at build time.
    @Test("the app embeds the widget")
    func embedded() throws {
        let all = try targets(in: makeConfiguration(widget: .init()))

        let app = try #require(all["Bookshelf"] as? [String: Any])
        let dependencies = try #require(app["dependencies"] as? [[String: Any]])
        let widget = try #require(dependencies.first { $0["target"] as? String == "BookshelfWidget" })
        #expect(widget["embed"] as? Bool == true)
    }

    @Test("omitted grows nothing")
    func absentWhenOmitted() throws {
        let all = try targets(in: makeConfiguration())

        #expect(all["BookshelfWidget"] == nil)
        let app = try #require(all["Bookshelf"] as? [String: Any])
        #expect(app["dependencies"] == nil)
    }
}

@Suite("The widget extension outside iOS")
struct WidgetExtensionCapabilityTests {
    /// WidgetKit exists on macOS; the templates and the target shape here do
    /// not, which makes this a boundary rather than an impossibility.
    @Test("macOS is refused as a capability boundary")
    func macOSIsRefused() {
        let issues = ConfigurationValidator().validate(makeConfiguration(
            widget: .init(),
            platform: .macOS
        ))

        #expect(issues.contains { $0.code == .widgetRequiresIOS })
    }

    @Test("a switched-off widget on macOS is fine")
    func disabledOnMacOSIsFine() {
        let issues = ConfigurationValidator().validate(makeConfiguration(
            widget: .init(enabled: false),
            platform: .macOS
        ))

        #expect(!issues.contains { $0.code == .widgetRequiresIOS })
    }
}
