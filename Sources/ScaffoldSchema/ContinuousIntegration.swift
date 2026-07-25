/// The `ci` section of `scaffold.yml` (§21): which provider's workflow files
/// the generated project carries, and which workflows. Omitted generates
/// nothing — CI is a choice, not a default.
public struct ContinuousIntegration: Codable, Equatable, Sendable {
    public var provider: CIProvider
    public var workflows: Workflows

    public init(provider: CIProvider? = nil, workflows: Workflows? = nil) {
        self.provider = provider ?? .gitHubActions
        self.workflows = workflows ?? Workflows()
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            provider: container.decodeIfPresent(CIProvider.self, forKey: .provider),
            workflows: container.decodeIfPresent(Workflows.self, forKey: .workflows)
        )
    }

    /// Three switches, each its own file. Stating `ci:` at all means CI is
    /// wanted, so an unstated switch is on — off is the choice to state.
    public struct Workflows: Codable, Equatable, Sendable {
        public var build: Bool
        public var test: Bool
        public var lint: Bool

        public init(build: Bool? = nil, test: Bool? = nil, lint: Bool? = nil) {
            self.build = build ?? true
            self.test = test ?? true
            self.lint = lint ?? true
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try self.init(
                build: container.decodeIfPresent(Bool.self, forKey: .build),
                test: container.decodeIfPresent(Bool.self, forKey: .test),
                lint: container.decodeIfPresent(Bool.self, forKey: .lint)
            )
        }
    }
}

/// The one provider this version writes workflows for (§21). An enum rather
/// than a constant so that a second provider is a new case, not a new field.
public enum CIProvider: String, ScaffoldEnum {
    case gitHubActions = "github-actions"
}
