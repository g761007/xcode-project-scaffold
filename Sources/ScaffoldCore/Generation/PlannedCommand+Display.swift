import ScaffoldSchema

extension PlannedCommand {
    /// The command as the user would type it.
    ///
    /// Arguments with spaces are quoted, because a message reporting
    /// `git commit --message Initial commit` reads as two arguments and cannot
    /// be pasted back into a shell.
    public var displayString: String {
        ([executable] + arguments.map(quoted)).joined(separator: " ")
    }

    private func quoted(_ argument: String) -> String {
        argument.contains(where: \.isWhitespace) || argument.isEmpty ? "'\(argument)'" : argument
    }
}
