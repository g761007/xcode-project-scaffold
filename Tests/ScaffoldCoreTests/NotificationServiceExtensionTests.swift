@testable import ScaffoldCore
import ScaffoldSchema
import Testing
import Yams

private func makeConfiguration(
    notificationService: AppExtensions.NotificationService? = nil,
    widget: AppExtensions.Widget? = nil,
    platform: ApplePlatform = .iOS
) -> ProjectConfiguration {
    ProjectConfiguration(
        project: .init(name: "Bookshelf", bundleIdentifier: "com.example.bookshelf"),
        product: .init(platform: platform),
        interface: .init(primary: .swiftUI),
        extensions: (notificationService == nil && widget == nil)
            ? nil
            : AppExtensions(widget: widget, notificationService: notificationService)
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

private func targets(in configuration: ProjectConfiguration) throws -> [String: Any] {
    let yaml = try XcodeGenSpecEncoder().encode(XcodeGenSpecBuilder().makeSpec(for: configuration))
    let document = try #require(Yams.load(yaml: yaml) as? [String: Any])
    return try #require(document["targets"] as? [String: Any])
}

/// Issue #82: `extensions.notificationService`. It shares every mechanism the
/// widget introduced — embedding, the identity suffix, the Features layer — so
/// these tests concentrate on what is genuinely different: the extension point
/// and the principal class the system instantiates by name.
@Suite("The notification service in the configuration")
struct NotificationServiceSchemaTests {
    let coder = ConfigurationCoder()

    @Test("naming the section is what asks for it")
    func namingItEnablesIt() throws {
        let decoded = try coder.decode("""
        project:
          name: App
          bundleIdentifier: com.example.app
        interface:
          primary: swiftui
        extensions:
          notificationService: {}
        """)

        #expect(decoded.generatesNotificationService)
        #expect(!decoded.generatesWidget, "the two sections are independent")
    }

    @Test("an omitted section generates nothing")
    func omittedIsOff() throws {
        let decoded = try coder.decode("""
        project:
          name: App
          bundleIdentifier: com.example.app
        interface:
          primary: swiftui
        extensions:
          widget: {}
        """)

        #expect(!decoded.generatesNotificationService)
    }

    @Test("an explicit false switches it off")
    func explicitFalseIsOff() throws {
        let decoded = try coder.decode("""
        project:
          name: App
          bundleIdentifier: com.example.app
        interface:
          primary: swiftui
        extensions:
          notificationService:
            enabled: false
        """)

        #expect(!decoded.generatesNotificationService)
    }

    @Test("the section round-trips")
    func roundTrips() throws {
        let configuration = makeConfiguration(notificationService: .init())

        #expect(try coder.decode(coder.encode(configuration)) == configuration)
    }
}

@Suite("The notification service in the plan")
struct NotificationServicePlanTests {
    @Test("enabled plans the service class")
    func enabledFiles() throws {
        let files = try planFiles(makeConfiguration(notificationService: .init()))

        #expect(files.contains("NotificationService/NotificationService.swift"))
    }

    @Test("omitted plans no NotificationService directory")
    func omittedFiles() throws {
        let files = try planFiles(makeConfiguration(widget: .init()))

        #expect(!files.contains { $0.hasPrefix("NotificationService/") })
    }

    /// The two extensions own separate directories, so asking for both is not
    /// a template conflict (§13.4).
    @Test("both extensions together plan both directories and nothing else")
    func bothTogether() throws {
        let files = try planFiles(makeConfiguration(notificationService: .init(), widget: .init()))

        #expect(files.contains("NotificationService/NotificationService.swift"))
        #expect(files.contains("Widget/BookshelfWidget.swift"))
        #expect(files.contains("Widget/BookshelfWidgetBundle.swift"))
    }
}

@Suite("The notification service in project.yml")
struct NotificationServiceSpecTests {
    /// The principal class is what a notification service has and a widget has
    /// not: the system instantiates it by name, so a target that omits it
    /// builds and then never runs.
    @Test("the target declares its extension point and its principal class")
    func target() throws {
        let all = try targets(in: makeConfiguration(notificationService: .init()))

        let service = try #require(all["BookshelfNotificationService"] as? [String: Any])
        #expect(service["type"] as? String == "app-extension")
        #expect(service["sources"] as? [String] == ["NotificationService"])

        let info = try #require(service["info"] as? [String: Any])
        let properties = try #require(info["properties"] as? [String: Any])
        let extensionPoint = try #require(properties["NSExtension"] as? [String: Any])
        #expect(extensionPoint["NSExtensionPointIdentifier"] as? String
            == "com.apple.usernotifications.service")
        #expect(extensionPoint["NSExtensionPrincipalClass"] as? String
            == "$(PRODUCT_MODULE_NAME).NotificationService")
    }

    /// WidgetKit finds its own `@main` bundle, so the widget must not grow a
    /// principal class just because its neighbour has one.
    @Test("the widget still declares no principal class")
    func widgetHasNoPrincipalClass() throws {
        let all = try targets(in: makeConfiguration(widget: .init()))

        let widget = try #require(all["BookshelfWidget"] as? [String: Any])
        let info = try #require(widget["info"] as? [String: Any])
        let properties = try #require(info["properties"] as? [String: Any])
        let extensionPoint = try #require(properties["NSExtension"] as? [String: Any])
        #expect(extensionPoint["NSExtensionPrincipalClass"] == nil)
    }

    @Test("it ships under the app's identity plus .notificationservice")
    func identity() throws {
        let all = try targets(in: makeConfiguration(notificationService: .init()))

        let service = try #require(all["BookshelfNotificationService"] as? [String: Any])
        let settings = try #require(service["settings"] as? [String: Any])
        let base = try #require(settings["base"] as? [String: Any])
        #expect(base["PRODUCT_BUNDLE_IDENTIFIER"] as? String
            == "com.example.bookshelf.notificationservice")
        #expect(base["PRODUCT_DISPLAY_NAME"] as? String == "Bookshelf Notification Service")
    }

    @Test("the app embeds it")
    func embedded() throws {
        let all = try targets(in: makeConfiguration(notificationService: .init()))

        let app = try #require(all["Bookshelf"] as? [String: Any])
        let dependencies = try #require(app["dependencies"] as? [[String: Any]])
        let service = try #require(dependencies
            .first { $0["target"] as? String == "BookshelfNotificationService" })
        #expect(service["embed"] as? Bool == true)
    }

    /// Both at once is the case the single-extension shape could not express,
    /// and the one a project that ships push notifications and a widget
    /// actually has.
    @Test("the app embeds both extensions when both are asked for")
    func bothEmbedded() throws {
        let all = try targets(in: makeConfiguration(notificationService: .init(), widget: .init()))

        #expect(all["BookshelfWidget"] != nil)
        #expect(all["BookshelfNotificationService"] != nil)

        let app = try #require(all["Bookshelf"] as? [String: Any])
        let dependencies = try #require(app["dependencies"] as? [[String: Any]])
        let embedded = dependencies.compactMap { $0["target"] as? String }
        #expect(embedded == ["BookshelfWidget", "BookshelfNotificationService"])
        #expect(dependencies.allSatisfy { $0["embed"] as? Bool == true })
    }

    @Test("omitted grows nothing")
    func absentWhenOmitted() throws {
        let all = try targets(in: makeConfiguration(widget: .init()))

        #expect(all["BookshelfNotificationService"] == nil)
    }
}

@Suite("The notification service outside iOS")
struct NotificationServiceCapabilityTests {
    @Test("macOS is refused as a capability boundary")
    func macOSIsRefused() {
        let issues = ConfigurationValidator().validate(makeConfiguration(
            notificationService: .init(),
            platform: .macOS
        ))

        #expect(issues.contains { $0.code == .notificationServiceRequiresIOS })
    }

    @Test("a switched-off service on macOS is fine")
    func disabledOnMacOSIsFine() {
        let issues = ConfigurationValidator().validate(makeConfiguration(
            notificationService: .init(enabled: false),
            platform: .macOS
        ))

        #expect(!issues.contains { $0.code == .notificationServiceRequiresIOS })
    }

    /// Each extension reports its own boundary, so a macOS project asking for
    /// both learns about both rather than fixing one and meeting the next.
    @Test("both extensions on macOS report both boundaries")
    func bothReported() {
        let issues = ConfigurationValidator().validate(makeConfiguration(
            notificationService: .init(),
            widget: .init(),
            platform: .macOS
        ))

        #expect(issues.contains { $0.code == .widgetRequiresIOS })
        #expect(issues.contains { $0.code == .notificationServiceRequiresIOS })
    }
}
