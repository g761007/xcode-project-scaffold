/// The `extensions` section of `scaffold.yml` (§11.6): which App Extension
/// targets the generated project carries. Omitted generates nothing — an
/// extension is a choice, not a default.
///
/// Each extension is its own optional sub-section rather than a switch on this
/// one, so that `extensions:` naming none of them stays as empty as omitting
/// it, and a second extension arrives as a new key instead of as a new meaning
/// for the ones already there.
public struct AppExtensions: Codable, Equatable, Sendable {
    public var widget: Widget?

    public init(widget: Widget? = nil) {
        self.widget = widget
    }

    /// A WidgetKit extension. Naming the section is what asks for it, so an
    /// unstated `enabled` is on; `false` exists so a project can park the
    /// section — with whatever it comes to hold — without generating the
    /// target.
    public struct Widget: Codable, Equatable, Sendable {
        public var enabled: Bool

        public init(enabled: Bool? = nil) {
            self.enabled = enabled ?? true
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try self.init(enabled: container.decodeIfPresent(Bool.self, forKey: .enabled))
        }
    }
}

extension ProjectConfiguration {
    /// Whether the project grows a widget extension. Asked by the templates,
    /// by the project file and by validation, so the two-level question —
    /// is the section there, and is it switched on — is answered in one place.
    public var generatesWidget: Bool {
        extensions?.widget?.enabled == true
    }
}
