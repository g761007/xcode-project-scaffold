import ScaffoldSchema

/// Renders what `localization.languages` becomes on disk (§16): one lproj per
/// shipped language. No languages renders nothing.
///
/// Its own type rather than a method on the plan builder, so that the file
/// manifest can name it the way it names `EnvironmentFilesRenderer` and the
/// rest — an origin earns its place in a conflict report only by being
/// somewhere a reader can go and look.
struct LocalizationRenderer: Sendable {
    /// Each strings file opens with a header rather than being empty: this tool
    /// never generates an empty folder, and an empty strings file explains
    /// itself worse than one line does.
    func files(for configuration: ProjectConfiguration) -> [PlannedFile] {
        configuration.localization.languages.map { language in
            PlannedFile(
                path: "Resources/\(language).lproj/Localizable.strings",
                contents: "/* \(language) strings for \(configuration.project.name). "
                    + "Add an entry per user-facing string. */\n"
            )
        }
    }
}
