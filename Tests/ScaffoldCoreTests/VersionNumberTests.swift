@testable import ScaffoldCore
import Testing

@Suite("Version numbers")
struct VersionNumberTests {
    @Test("well-formed versions parse", arguments: [
        ("18", [18]), ("18.0", [18, 0]), ("26.1.2", [26, 1, 2])
    ])
    func parses(text: String, components: [Int]) throws {
        #expect(try #require(VersionNumber(text)).components == components)
    }

    @Test("malformed versions do not parse", arguments: [
        "", "eighteen", "18.", ".0", "18.x", "18..0", "18.0.0.1", "-1", "18.٠", " 18.0"
    ])
    func rejectsMalformed(text: String) {
        #expect(VersionNumber(text) == nil)
    }

    /// An overflowing component is a rejection, not a trap.
    @Test("an out-of-range component is rejected")
    func rejectsOverflow() {
        #expect(VersionNumber("99999999999999999999") == nil)
    }

    /// The whole reason this is not a `Double`: as a number, 18.10 < 18.9.
    @Test("10 sorts above 9 in the minor position")
    func minorComponentsAreNotDecimals() throws {
        let ten = try #require(VersionNumber("18.10"))
        let nine = try #require(VersionNumber("18.9"))

        #expect(nine < ten)
        #expect(!(ten < nine))
    }

    /// `Comparable` requires that two values which are neither less than one
    /// another compare equal. Synthesised `==` compares the raw arrays, so
    /// `18` and `18.0` would satisfy neither — breaking `sorted`, `min` and
    /// `Set` for anyone who used them later.
    @Test("trailing zeros do not change a version's identity")
    func zeroPaddingIsConsistent() throws {
        let short = try #require(VersionNumber("18"))
        let long = try #require(VersionNumber("18.0.0"))

        #expect(short == long)
        #expect(!(short < long))
        #expect(!(long < short))
        #expect([long, short].sorted() == [long, short])
    }

    @Test("ordering across major versions")
    func ordersByMajorFirst() throws {
        #expect(try #require(VersionNumber("15.9")) < #require(VersionNumber("18.0")))
        #expect(try #require(VersionNumber("18.0")) < #require(VersionNumber("26.0")))
    }
}
