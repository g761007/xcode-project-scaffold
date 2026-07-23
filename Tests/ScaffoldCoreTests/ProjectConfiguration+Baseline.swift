@testable import ScaffoldCore
import ScaffoldSchema

extension ProjectConfiguration {
    /// The smallest configuration this version can actually generate. Each
    /// validation test starts here and breaks exactly one thing, so a failure
    /// names the rule under test rather than a pile of unrelated issues.
    static var validBaseline: ProjectConfiguration {
        ProjectConfiguration(
            project: .init(name: "MyApp", bundleIdentifier: "com.example.myapp"),
            interface: .init(primary: .uiKit)
        )
    }

    func with(_ mutate: (inout ProjectConfiguration) -> Void) -> ProjectConfiguration {
        var copy = self
        mutate(&copy)
        return copy
    }
}

/// Shared by every validation suite: the codes a configuration produces, in
/// order, with the messages stripped away.
func codes(_ configuration: ProjectConfiguration) -> [ValidationCode] {
    ConfigurationValidator().validate(configuration).map(\.code)
}
