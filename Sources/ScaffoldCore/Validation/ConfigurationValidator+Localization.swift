import Foundation
import ScaffoldSchema

// The §16 localization checks, apart only for file size: the same validator,
// the same two-group contract.

extension ConfigurationValidator {
    /// A localized project lists every language it ships, the development
    /// language included — Xcode's own convention — and lists each once.
    func localizationIssues(_ configuration: ProjectConfiguration) -> [ValidationIssue] {
        let localization = configuration.localization
        guard !localization.languages.isEmpty else { return [] }

        var issues: [ValidationIssue] = []

        if !localization.languages.contains(localization.developmentLanguage) {
            issues.append(ValidationIssue(
                code: .developmentLanguageNotListed,
                message: "languages does not include the development language "
                    + "'\(localization.developmentLanguage)'.",
                path: "localization.languages",
                suggestion: "List every language the project ships, the development language included."
            ))
        }

        issues += duplicates(localization.languages, ignoringCase: false).map { index, language in
            ValidationIssue(
                code: .duplicateLanguage,
                message: "Language '\(language)' is listed more than once.",
                path: "localization.languages[\(index)]",
                suggestion: "List each language once."
            )
        }

        return issues
    }
}
