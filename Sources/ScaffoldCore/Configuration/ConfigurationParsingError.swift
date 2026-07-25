import Foundation
import ScaffoldSchema

/// A `scaffold.yml` that could not be turned into a `ProjectConfiguration`.
///
/// Deliberately not a `DecodingError`: the CLI surfaces this text directly to
/// users and to agents, and a raw decoder trace tells neither of them which
/// line to edit.
public struct ConfigurationParsingError: Error, Equatable, Sendable {
    /// A sentence the reader can act on.
    public let message: String

    /// Dotted path to the offending field, e.g. `interface.primary`.
    /// `nil` when the failure is not attributable to one field — a document
    /// that is not YAML at all, or one whose top level has the wrong shape.
    public let path: String?

    public init(message: String, path: String? = nil) {
        self.message = message
        self.path = path
    }
}

/// A document that states a schema version this binary does not understand.
///
/// Refused before decoding rather than reported as a validation issue, because
/// once the version is unknown nothing else the document says can be trusted:
/// the decoder ignores keys it does not recognise, so field-level advice about
/// a newer document would be advice about the part of it that survived.
public struct UnsupportedSchemaVersionError: Error, Equatable, Sendable {
    public let stated: Int
    public let supported: [Int]

    public init(stated: Int, supported: [Int]) {
        self.stated = stated
        self.supported = supported
    }
}

extension UnsupportedSchemaVersionError: ReportableError {
    public var errorCode: ScaffoldErrorCode {
        .schemaVersionUnsupported
    }
}

extension UnsupportedSchemaVersionError: CustomStringConvertible {
    public var description: String {
        "This scaffold.yml states schemaVersion \(stated), and this version of xscaffold "
            + "understands \(supported.map(String.init).joined(separator: ", "))."
    }
}

extension ConfigurationParsingError: CustomStringConvertible {
    public var description: String {
        guard let path else { return message }
        return "\(path): \(message)"
    }
}

extension ConfigurationParsingError {
    /// Translates the decoder's vocabulary into something the reader can act on.
    static func from(_ error: DecodingError) -> ConfigurationParsingError {
        switch error {
        case let .keyNotFound(key, context):
            // Always attributable: the missing key completes the path.
            let path = dottedPath(context.codingPath + [key]) ?? key.stringValue
            return ConfigurationParsingError(message: "Required field '\(path)' is missing.", path: path)

        case let .valueNotFound(_, context):
            let path = dottedPath(context.codingPath)
            return ConfigurationParsingError(
                message: path.map { "Field '\($0)' has no value." } ?? "A required value is missing.",
                path: path
            )

        case let .typeMismatch(type, context):
            let path = dottedPath(context.codingPath)
            let expected = describe(type)
            return ConfigurationParsingError(
                message: path.map { "Field '\($0)' expects \(expected)." }
                    ?? "The document expects \(expected) at its top level.",
                path: path
            )

        case let .dataCorrupted(context):
            // Already actionable: `ScaffoldEnum` names the offending value and
            // lists the allowed set when a value is unrecognised.
            return ConfigurationParsingError(
                message: context.debugDescription,
                path: dottedPath(context.codingPath)
            )

        @unknown default:
            return ConfigurationParsingError(message: error.localizedDescription)
        }
    }

    /// `["interface", "primary"]` becomes `interface.primary`;
    /// `["environments", 0, "name"]` becomes `environments[0].name`.
    /// Returns `nil` for the document root.
    private static func dottedPath(_ codingPath: [any CodingKey]) -> String? {
        var path = ""
        for key in codingPath {
            if let index = key.intValue {
                path += "[\(index)]"
            } else if path.isEmpty {
                path = key.stringValue
            } else {
                path += ".\(key.stringValue)"
            }
        }
        return path.isEmpty ? nil : path
    }

    private static func describe(_ type: Any.Type) -> String {
        switch type {
        case is Bool.Type: return "true or false"
        case is Int.Type: return "a whole number"
        case is String.Type: return "a string"
        default:
            let name = String(describing: type)
            return name.hasPrefix("Array<") || name.hasPrefix("[")
                ? "a list"
                : "a block of settings"
        }
    }
}
