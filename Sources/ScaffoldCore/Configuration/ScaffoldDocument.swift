import ScaffoldSchema

/// A `scaffold.yml` as this tool writes it: the encoded configuration under the
/// schema annotation an editor reads to complete and check the file.
///
/// One type rather than one per writer. `generate` records this file in the
/// project it creates and `config example` prints it for someone to redirect
/// into place — a starting point that differed from what generation records
/// would be a trap the first time anyone diffed the two.
///
/// The annotation is this type's addition rather than `ConfigurationCoder`'s:
/// the coder stays a pure value<->text mapping, and decode tolerates the
/// comment the way it tolerates any other.
public struct ScaffoldDocument: Sendable {
    static let schemaURL =
        "https://raw.githubusercontent.com/g761007/xcode-project-scaffold/main/Schemas/scaffold.schema.json"

    private let coder = ConfigurationCoder()

    public init() {}

    public func text(for configuration: ProjectConfiguration) throws -> String {
        try "# yaml-language-server: $schema=" + Self.schemaURL + "\n" + coder.encode(configuration)
    }
}
