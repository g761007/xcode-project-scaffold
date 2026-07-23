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
            return try YAMLDecoder().decode(ProjectConfiguration.self, from: yaml)
        } catch let error as DecodingError {
            throw ConfigurationParsingError.from(error)
        } catch let error as YamlError {
            throw ConfigurationParsingError(message: "The document is not valid YAML. \(error)")
        }
    }

    public func encode(_ configuration: ProjectConfiguration) throws -> String {
        // Key order follows property declaration order rather than being
        // sorted, so an encoded document reads in the same order as the
        // documented schema — and so encoding is deterministic.
        try YAMLEncoder().encode(configuration)
    }
}
