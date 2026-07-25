/// What `scaffold.yml` may say about secrets, and all it may say (§14): the
/// key's name and an example value. There is no field for an actual secret —
/// that absence is the design, not an omission. The real file lives at the
/// conventional `Configurations/Secrets.xcconfig`, git-ignored.
public struct Secrets: Codable, Equatable, Sendable {
    public var keys: [SecretKey]

    public init(keys: [SecretKey] = []) {
        self.keys = keys
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(keys: container.decodeIfPresent([SecretKey].self, forKey: .keys) ?? [])
    }

    public struct SecretKey: Codable, Equatable, Sendable {
        public var name: String
        /// Written into the example file, and into the initial real file so a
        /// fresh clone builds — obviously fake, so it gets replaced.
        public var example: String

        public init(name: String, example: String) {
            self.name = name
            self.example = example
        }
    }
}
