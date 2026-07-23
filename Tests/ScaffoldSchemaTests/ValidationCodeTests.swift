import Foundation
@testable import ScaffoldSchema
import Testing

@Suite("Validation code contract")
struct ValidationCodeTests {
    // Uniqueness is not tested: two cases sharing a raw value do not compile,
    // so the assertion could never fail.

    @Test("every code is XS followed by four digits")
    func codesAreWellFormed() {
        for code in ValidationCode.allCases {
            #expect(code.rawValue.wholeMatch(of: /XS\d{4}/) != nil, "\(code.rawValue)")
        }
    }

    /// The prefix is the contract: a user reading `XS0001` must be able to
    /// conclude "not yet" without consulting a table, and `XS1001` must mean
    /// "never".
    @Test("the numeric prefix determines the category")
    func prefixDeterminesCategory() {
        for code in ValidationCode.allCases {
            let expected: ValidationCode.Category = code.rawValue.hasPrefix("XS0")
                ? .capabilityBoundary
                : .permanentlyInvalid
            #expect(code.category == expected, "\(code.rawValue)")
        }
    }

    @Test("both categories are actually in use")
    func bothCategoriesAreUsed() {
        let categories = Set(ValidationCode.allCases.map(\.category))

        #expect(categories == [.capabilityBoundary, .permanentlyInvalid])
    }
}

@Suite("Validation issue wire format")
struct ValidationIssueWireFormatTests {
    @Test("severity encodes as its lowercase name")
    func severityWireFormat() {
        #expect(ValidationSeverity.error.rawValue == "error")
        #expect(ValidationSeverity.warning.rawValue == "warning")
    }

    /// The code must appear in JSON as the bare string users see in the docs,
    /// not as a Swift case name.
    @Test("an issue encodes the code as its raw value")
    func issueEncodesRawCode() throws {
        let issue = ValidationIssue(
            code: .uiKitRequiresIOS,
            message: "UIKit is only available for iOS projects.",
            path: "interface.primary",
            suggestion: "Set product.platform to ios."
        )

        let json = try JSONEncoder().encode(issue)
        let decoded = try JSONSerialization.jsonObject(with: json) as? [String: Any]

        #expect(decoded?["code"] as? String == "XS1001")
        #expect(decoded?["severity"] as? String == "error")
        #expect(decoded?["path"] as? String == "interface.primary")
    }

    @Test("an issue round-trips")
    func issueRoundTrips() throws {
        let issue = ValidationIssue(
            severity: .warning,
            code: .deploymentTargetNotSupported,
            message: "message",
            path: "product.deploymentTarget",
            suggestion: nil
        )

        let decoded = try JSONDecoder().decode(ValidationIssue.self, from: JSONEncoder().encode(issue))

        #expect(decoded == issue)
    }
}
