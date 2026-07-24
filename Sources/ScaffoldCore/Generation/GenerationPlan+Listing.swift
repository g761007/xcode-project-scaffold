import ScaffoldSchema

extension GenerationPlan {
    /// The long form of the plan — every file, then every command with its
    /// purpose — printed by the preview's "Show complete file plan" and by
    /// `plan --files`. One renderer, so the menu and the flag cannot drift.
    public var listing: [String] {
        var lines = ["Files:"]
        lines += files.map { "  \($0.path)" }
        if !commands.isEmpty {
            lines.append("Commands:")
            lines += commands.map { "  \($0.displayString)  — \($0.purpose)" }
        }
        return lines
    }
}
