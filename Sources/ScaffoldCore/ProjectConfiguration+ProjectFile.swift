import ScaffoldSchema

extension ProjectConfiguration {
    /// What the generator will call the project file.
    ///
    /// Derived in one place because more than one caller needs it — the plan,
    /// to explain what the generator is for, and the CLI, to tell the user what
    /// to open — and a second derivation is a second thing to keep in step.
    public var projectFileName: String {
        "\(project.name).xcodeproj"
    }
}
