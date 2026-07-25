import ScaffoldSchema

/// One kind of App Extension this version generates.
///
/// A widget and a notification service differ in a handful of strings and in
/// nothing else: both are app-extension targets the app embeds, both ship
/// under the app's identity plus a suffix, both bring a directory of sources
/// from the Features layer, and both are iOS-only for now. Those strings live
/// here, once, so that a third extension is an entry in `all` rather than a
/// third copy of the machinery around it.
///
/// The widget alone did not earn this — one call site needs no table. The
/// second one does.
struct AppExtensionKind: Sendable {
    /// The directory under `Templates/Features/`, the sources directory in the
    /// generated project, and the suffix on the target's name. One word for
    /// all three: three spellings would be three things to keep in step.
    let directoryName: String

    /// Appended to the app's bundle identifier. Not cosmetic — an extension
    /// whose identifier is not prefixed by its container's cannot be installed.
    let identifierSuffix: String

    let displayNameSuffix: String

    /// What makes the bundle this kind of extension rather than another.
    let extensionPointIdentifier: String

    /// The class the system instantiates to run the extension. A notification
    /// service is a named subclass looked up at delivery time; a widget has no
    /// such entry point, because WidgetKit finds its `@main` bundle instead.
    /// A target that needs one and omits it builds, installs, and never runs.
    let principalClass: String?

    /// The section that asks for it, for validation paths.
    let configurationPath: String

    /// Whether a configuration asks for this kind. Carried by the kind rather
    /// than decided in a switch elsewhere, so the schema property that already
    /// answers the question is the only thing that answers it.
    let isEnabled: @Sendable (ProjectConfiguration) -> Bool

    /// How validation names this kind, plural, to open the sentence "… are
    /// only generated for iOS in this version."
    let noun: String

    /// The capability-boundary code its iOS-only rule reports. One per kind,
    /// because a user who switches off the one they were told about must not
    /// then be told the same code about the other.
    let platformCode: ValidationCode

    static let widget = AppExtensionKind(
        directoryName: "Widget",
        identifierSuffix: ".widget",
        displayNameSuffix: " Widget",
        extensionPointIdentifier: "com.apple.widgetkit-extension",
        principalClass: nil,
        configurationPath: "extensions.widget",
        isEnabled: { $0.generatesWidget },
        noun: "Widget extensions",
        platformCode: .widgetRequiresIOS
    )

    static let notificationService = AppExtensionKind(
        directoryName: "NotificationService",
        identifierSuffix: ".notificationservice",
        displayNameSuffix: " Notification Service",
        extensionPointIdentifier: "com.apple.usernotifications.service",
        // Resolved at build time to `<TargetName>.NotificationService`, which
        // is where the template puts the class.
        principalClass: "$(PRODUCT_MODULE_NAME).NotificationService",
        configurationPath: "extensions.notificationService",
        isEnabled: { $0.generatesNotificationService },
        noun: "Notification Service extensions",
        platformCode: .notificationServiceRequiresIOS
    )

    /// Every kind, in the order they reach the project file. Fixed rather than
    /// derived, so `project.yml` does not churn between runs.
    static let all: [AppExtensionKind] = [.widget, .notificationService]
}

extension AppExtensionKind {
    /// The kinds this configuration asks for, in `all`'s order.
    static func enabled(in configuration: ProjectConfiguration) -> [AppExtensionKind] {
        all.filter { $0.isEnabled(configuration) }
    }

    /// The target this kind becomes in a project of the given name.
    func targetName(in projectName: String) -> String {
        projectName + directoryName
    }
}
