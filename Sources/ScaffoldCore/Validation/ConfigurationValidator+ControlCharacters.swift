import Foundation
import ScaffoldSchema

extension ConfigurationValidator {
    /// Refuses a control character anywhere in the document.
    ///
    /// Almost every file a run writes is line-oriented — an xcconfig is
    /// `KEY = value` per line, a Podfile is Ruby, a Makefile is tab-indented
    /// recipes — so a newline inside a value does not stay a value. It was
    /// possible to write
    ///
    ///     values:
    ///       API_BASE_URL: "https://x\nOTHER_LDFLAGS = -whatever"
    ///
    /// and get two build settings out of one reviewed line. The document is
    /// meant to be readable and reviewable (§4, "have it reviewed"), and a
    /// value that renders as more than itself defeats exactly that.
    ///
    /// Checked over the whole document rather than field by field. A list of
    /// fields is a list that goes stale — `cocoapodsVersion` was already
    /// missing from the published JSON Schema for three versions — and there is
    /// no field where a control character is meaningful, so the general rule is
    /// both safer and shorter than the enumeration.
    func controlCharacterIssues(_ configuration: ProjectConfiguration) -> [ValidationIssue] {
        strings(in: configuration)
            .filter { $0.value.contains(where: \.isControl) }
            .map { path, value in
                ValidationIssue(
                    code: .controlCharacterInValue,
                    message: "'\(value.escapingControlCharacters)' contains a control character.",
                    path: path,
                    suggestion: "Remove it. Every file this value is written into is line-oriented, "
                        + "so a newline in it becomes a line of its own."
                )
            }
    }

    /// Every string in the document, with the path that would name it in an
    /// issue. Read off the encoded form, so a field added to the schema is
    /// covered the day it exists.
    private func strings(in configuration: ProjectConfiguration) -> [(path: String, value: String)] {
        guard let data = try? JSONEncoder().encode(configuration),
              let object = try? JSONSerialization.jsonObject(with: data)
        else { return [] }

        return strings(in: object).sorted { $0.path < $1.path }
    }

    private func strings(in value: Any, prefix: String = "") -> [(path: String, value: String)] {
        switch value {
        case let text as String:
            prefix.isEmpty ? [] : [(prefix, text)]
        case let object as [String: Any]:
            object.flatMap { key, child in
                strings(in: child, prefix: prefix.isEmpty ? key : "\(prefix).\(key)")
            }
        case let array as [Any]:
            array.enumerated().flatMap { index, element in
                strings(in: element, prefix: "\(prefix)[\(index)]")
            }
        default:
            []
        }
    }
}

extension Character {
    /// Anything that is not a printable character or a plain space. Tabs and
    /// newlines included: neither is meaningful in any field of this document,
    /// and both change the shape of a file they are written into.
    var isControl: Bool {
        unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }
}

extension String {
    /// The value as a reader can see it in an error message. Printing the raw
    /// string would put the newline in the message and hide the problem it is
    /// reporting.
    var escapingControlCharacters: String {
        unicodeScalars.map { scalar in
            guard CharacterSet.controlCharacters.contains(scalar) else { return String(scalar) }
            switch scalar {
            case "\n": return "\\n"
            case "\r": return "\\r"
            case "\t": return "\\t"
            default: return String(format: "\\u{%02X}", scalar.value)
            }
        }
        .joined()
    }
}
