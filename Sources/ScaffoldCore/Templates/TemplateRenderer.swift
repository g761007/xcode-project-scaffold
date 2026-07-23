import Foundation

/// A placeholder that could not be resolved.
///
/// Rendering fails rather than leaving `{{PROJECT_NAME}}` in a Swift file: the
/// result would usually still compile — placeholders sit in comments and string
/// literals too — and the mistake would surface as a puzzling generated project
/// rather than as an error.
public struct TemplateRenderingError: Error, Equatable, Sendable {
    public enum Reason: Equatable, Sendable {
        /// No value was supplied for a well-formed placeholder.
        case noValue
        /// `{{` with no matching `}}`. Almost always a typo, and treating it as
        /// literal text would hide it.
        case unterminated
        /// A name that cannot be a placeholder, such as `{{ SPACED }}` or the
        /// inner half of `{{{{X}}}}`. Reported separately so the message can
        /// say what is wrong rather than "no value for '{{X'".
        case malformedName
    }

    public let placeholder: String
    public let templatePath: String
    public let reason: Reason

    public var message: String {
        switch reason {
        case .noValue:
            "\(templatePath) uses {{\(placeholder)}}, which has no value."
        case .unterminated:
            "\(templatePath) has an unterminated {{ with no closing }}."
        case .malformedName:
            "\(templatePath) has a malformed placeholder: {{\(placeholder)}}."
        }
    }
}

/// Substitutes `{{NAME}}` placeholders in template text and in template paths.
///
/// Deliberately not a template language: no conditionals, no loops, no
/// includes. Anything that varies structurally is decided in Swift and reaches
/// the template as a value, which keeps the templates readable as the files
/// they will become.
struct TemplateRenderer: Sendable {
    static let opening = "{{"
    static let closing = "}}"

    /// Upper case, digits and underscores. Narrow on purpose: it makes
    /// `{{{{X}}}}` and `{{ X }}` failures rather than confusing lookups.
    private static let allowedNameCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
    )

    func render(_ template: String, path: String, with values: [String: String]) throws -> String {
        var result = ""
        var remainder = Substring(template)

        while let start = remainder.range(of: Self.opening) {
            guard let end = remainder.range(of: Self.closing, range: start.upperBound ..< remainder.endIndex)
            else {
                throw TemplateRenderingError(placeholder: "", templatePath: path, reason: .unterminated)
            }

            let name = String(remainder[start.upperBound ..< end.lowerBound])
            guard !name.isEmpty,
                  name.unicodeScalars.allSatisfy(Self.allowedNameCharacters.contains)
            else {
                throw TemplateRenderingError(
                    placeholder: name,
                    templatePath: path,
                    reason: .malformedName
                )
            }
            guard let value = values[name] else {
                throw TemplateRenderingError(placeholder: name, templatePath: path, reason: .noValue)
            }

            result += remainder[remainder.startIndex ..< start.lowerBound]
            result += value
            remainder = remainder[end.upperBound...]
        }

        return result + remainder
    }
}
