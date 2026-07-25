@testable import ScaffoldCore
import ScaffoldSchema
import Testing

private func document(schemaVersion: String?) -> String {
    (schemaVersion.map { "schemaVersion: \($0)\n" } ?? "") + """
    project:
      name: Bookshelf
      bundleIdentifier: com.example.bookshelf
    interface:
      primary: swiftui
    """
}

/// #115: `schemaVersion` was written into every generated document and never
/// read back, so a document from a later version decoded as though it were
/// version 1 — silently dropping the keys that version had added, and
/// generating a project missing whatever they asked for. For a tool whose
/// premise is that one document means one project, that is the one failure it
/// cannot have.
@Suite("The schema version is a claim the coder checks")
struct SchemaVersionTests {
    private let coder = ConfigurationCoder()

    @Test("a supported version decodes")
    func supported() throws {
        let configuration = try coder.decode(document(schemaVersion: "1"))

        #expect(configuration.schemaVersion == 1)
    }

    /// Unstated is not a claim, and the default has always been 1. A document
    /// written by hand is the usual case and has to keep working.
    @Test("an unstated version takes the default")
    func unstated() throws {
        let configuration = try coder.decode(document(schemaVersion: nil))

        #expect(configuration.schemaVersion == ConfigurationDefaults.schemaVersion)
    }

    @Test("a version from the future is refused, naming both numbers")
    func fromTheFuture() throws {
        let error = #expect(throws: UnsupportedSchemaVersionError.self) {
            try coder.decode(document(schemaVersion: "2"))
        }

        #expect(try #require(error).stated == 2)
        #expect(try #require(error).supported == ConfigurationDefaults.supportedSchemaVersions)
        #expect(try #require(error).description.contains("schemaVersion 2"))
    }

    @Test("a version that never existed is refused too")
    func nonsense() {
        #expect(throws: UnsupportedSchemaVersionError.self) {
            try coder.decode(document(schemaVersion: "0"))
        }
    }

    /// The reason the check reads the document rather than the decoded value:
    /// afterwards, an unstated version and a stated `1` are the same number,
    /// and only one of them was a claim.
    @Test("the refusal carries the contract's own code")
    func errorCode() {
        let error = UnsupportedSchemaVersionError(stated: 2, supported: [1])

        #expect(error.errorCode == .schemaVersionUnsupported)
        #expect(error.errorCode.exitCode == .configurationParsingFailure)
        #expect(error.reportedPhase == .configuration)
    }

    /// `capabilities` is what an agent consults to predict what this binary
    /// accepts. A version it reported and then refused would make it useless.
    @Test("capabilities reports exactly the versions the coder accepts")
    func capabilitiesAgree() {
        let capabilities = CapabilitiesDocument.current(version: "0.9.0")

        #expect(capabilities.schemaVersions == ConfigurationDefaults.supportedSchemaVersions)
    }
}
