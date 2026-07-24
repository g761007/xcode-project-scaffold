import Foundation
import ScaffoldSchema

// The §14 value-key checks, apart only for file size: the same validator, the
// same two-group contract.

extension ConfigurationValidator {
    /// Keys become build settings and Info.plist entries; a name neither
    /// accepts is caught here rather than as a silently ignored xcconfig line.
    func valueKeyIssues(_ configuration: ProjectConfiguration) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        for (index, environment) in configuration.environments.enumerated() {
            issues += environment.values.keys.sorted()
                .filter { !isUsableValueKey($0) }
                .map { key in
                    malformedKey(key, at: "environments[\(index)].values")
                }
        }

        issues += (configuration.secrets?.keys ?? []).enumerated()
            .filter { !isUsableValueKey($0.element.name) }
            .map { index, key in
                malformedKey(key.name, at: "secrets.keys[\(index)].name")
            }

        return issues
    }

    private func malformedKey(_ key: String, at path: String) -> ValidationIssue {
        ValidationIssue(
            code: .invalidValueKey,
            message: "Value key '\(key)' cannot be used as a build setting.",
            path: path,
            suggestion: "Use ASCII letters, digits and underscores, not starting with a digit — "
                + "such as 'API_BASE_URL'."
        )
    }

    private func isUsableValueKey(_ key: String) -> Bool {
        guard let first = key.first, first.isASCII, first.isLetter || first == "_" else { return false }
        return key.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }
    }
}
