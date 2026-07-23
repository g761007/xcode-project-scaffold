import ScaffoldSchema

// How the contract's own types read on a terminal.
//
// On the types themselves rather than on whatever happens to be printing them:
// how a `ValidationIssue` reads is a property of the issue, and every command
// that shows one should show it the same way.

extension ValidationIssue {
    /// Code first, because it is the part a reader looks up or searches for.
    var report: String {
        var lines = ["\(code.rawValue)  \(path ?? "scaffold.yml")"]
        lines.append("    \(message)")
        if let suggestion {
            lines.append("    \(suggestion)")
        }
        return lines.joined(separator: "\n")
    }
}

extension EnvironmentCheck {
    /// Aligned in a column, so a list of them can be read down rather than
    /// across. A missing optional tool is not "MISSING": it is a fact, not a
    /// problem.
    var report: String {
        let mark = found ? "ok     " : (required ? "MISSING" : "absent ")
        return "\(mark) \(name)\(detail.map { "  \($0)" } ?? "")"
    }
}
