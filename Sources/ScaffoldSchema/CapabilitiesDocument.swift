/// What `capabilities` reports (§19): the machine-readable answer to "what
/// can this binary generate?", consulted by agents instead of guessing.
/// The shape lives here with the other wire types; what fills it lives in
/// core, next to the validator whose accepted sets it mirrors.
public struct CapabilitiesDocument: Codable, Equatable, Sendable {
    public var version: String
    public var schemaVersions: [Int]
    public var variants: [String]
    public var platforms: [String]
    public var architectures: [String]
    public var dependencyManagementModes: [String]
    public var testingFrameworks: [String]
    public var features: [String]

    public init(
        version: String,
        schemaVersions: [Int],
        variants: [String],
        platforms: [String],
        architectures: [String],
        dependencyManagementModes: [String],
        testingFrameworks: [String],
        features: [String]
    ) {
        self.version = version
        self.schemaVersions = schemaVersions
        self.variants = variants
        self.platforms = platforms
        self.architectures = architectures
        self.dependencyManagementModes = dependencyManagementModes
        self.testingFrameworks = testingFrameworks
        self.features = features
    }
}
