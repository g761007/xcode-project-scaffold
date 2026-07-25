import Foundation
import ScaffoldSchema
import Yams

/// Converts between `scaffold.yml` text and `ProjectConfiguration`.
///
/// Text in, value out — this type never touches the file system. Reading and
/// writing files belongs to the layer above, which keeps the coder trivially
/// testable and keeps `scaffold.yml` parsing free of I/O failure modes.
public struct ConfigurationCoder: Sendable {
    public init() {}

    public func decode(_ yaml: String) throws -> ProjectConfiguration {
        guard !yaml.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConfigurationParsingError(message: "The document is empty.")
        }

        do {
            // The preset overlay runs on the parsed document, before decoding,
            // so that its defaults reach only the fields this document leaves
            // unstated (ADR-0008). With no preset named it changes nothing.
            guard let node = try Yams.compose(yaml: yaml) else {
                throw ConfigurationParsingError(message: "The document is empty.")
            }
            let resolved = try PresetResolution.resolved(node)
            try checkSchemaVersion(of: resolved)
            return try YAMLDecoder().decode(ProjectConfiguration.self, from: resolved)
        } catch let error as DecodingError {
            throw ConfigurationParsingError.from(error)
        } catch let error as YamlError {
            throw ConfigurationParsingError(message: "The document is not valid YAML. \(error)")
        }
    }

    /// Read off the document rather than off the decoded value, because by
    /// then an unstated version and a stated `1` are the same thing — and only
    /// one of them is a claim.
    ///
    /// A version this binary does not understand ends the read here. Anything
    /// the document says beyond it is written in a dialect this binary cannot
    /// be sure it is reading.
    private func checkSchemaVersion(of node: Node) throws {
        guard let stated = node.mapping?["schemaVersion"]?.int else { return }
        guard !ConfigurationDefaults.supportedSchemaVersions.contains(stated) else { return }

        throw UnsupportedSchemaVersionError(
            stated: stated,
            supported: ConfigurationDefaults.supportedSchemaVersions
        )
    }

    public func encode(_ configuration: ProjectConfiguration) throws -> String {
        // Key order follows property declaration order rather than being
        // sorted, so an encoded document reads in the same order as the
        // documented schema — and so encoding is deterministic.
        try YAMLEncoder().encode(configuration)
    }
}
