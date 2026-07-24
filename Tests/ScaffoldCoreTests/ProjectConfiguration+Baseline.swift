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

    /// The proof `makePlan` requires. Fixtures are valid by construction, so a
    /// throw here means the fixture is broken, not the code under test.
    func validated() throws -> ValidatedConfiguration {
        switch ConfigurationValidator().check(self) {
        case let .valid(validated, _): validated
        case let .invalid(issues): throw BrokenFixture(issues: issues)
        }
    }
}

struct BrokenFixture: Error, CustomStringConvertible {
    let issues: [ValidationIssue]
    var description: String {
        "The fixture no longer validates:\n"
            + issues.map { "\($0.code.rawValue): \($0.message)" }.joined(separator: "\n")
    }
}

extension GenerationPlanBuilder {
    /// Validates then plans, keeping test call sites in the shape they were
    /// written in — and making a fixture that stops being generatable fail
    /// loudly here instead of as a template lookup error downstream.
    func makePlan(
        for configuration: ProjectConfiguration,
        options: GenerationOptions = GenerationOptions()
    ) throws -> GenerationPlan {
        try makePlan(for: configuration.validated(), options: options)
    }
}

/// Shared by every validation suite: the codes a configuration produces, in
/// order, with the messages stripped away.
func codes(_ configuration: ProjectConfiguration) -> [ValidationCode] {
    ConfigurationValidator().validate(configuration).map(\.code)
}
