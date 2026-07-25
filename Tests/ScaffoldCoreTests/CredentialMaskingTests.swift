@testable import ScaffoldCore
import ScaffoldSchema
import Testing

/// Issue #79: a private spec repo's URL carries the credential
/// (`https://user:token@host`), and that token must not reach logs, error
/// messages or JSON output — while the user's own files keep the original.
@Suite("Masking credentials in source URLs")
struct CredentialMaskingTests {
    @Test("the userinfo is replaced, whole", arguments: [
        ("https://ci:s3cret@enterprise.example.com/specs.git", "https://***@enterprise.example.com/specs.git"),
        ("https://token@example.com/specs.git", "https://***@example.com/specs.git"),
        ("http://a:b@example.com", "http://***@example.com")
    ])
    func masksUserinfo(url: String, expected: String) {
        #expect(CredentialMasking.masked(url) == expected)
    }

    /// Unconditional application must be safe: a URL with nothing to hide —
    /// or an `@` that is not userinfo — comes back byte-identical.
    @Test("a URL without userinfo is untouched", arguments: [
        "https://cdn.cocoapods.org/",
        "https://example.com/path@thing",
        "git@github.com:example/specs.git",
        ""
    ])
    func leavesCleanURLs(url: String) {
        #expect(CredentialMasking.masked(url) == url)
    }

    @Test("a masked configuration differs only in its source URLs")
    func masksConfiguration() {
        let original = ProjectConfiguration(
            project: .init(name: "MyApp", bundleIdentifier: "com.example.myapp"),
            interface: .init(primary: .swiftUI),
            dependencyManagement: .init(mode: .cocoapods, cocoapods: .init(
                sources: ["https://ci:s3cret@example.com/specs.git", "https://cdn.cocoapods.org/"],
                pods: [Pod(name: "SnapKit", source: .version("5.7.0"))]
            ))
        )

        let shown = CredentialMasking.masked(original)

        #expect(shown.dependencyManagement.cocoapods?.sources == [
            "https://***@example.com/specs.git",
            "https://cdn.cocoapods.org/"
        ])
        #expect(shown.dependencyManagement.cocoapods?.pods == original.dependencyManagement.cocoapods?.pods)
        #expect(original.dependencyManagement.cocoapods?.sources.first?.contains("s3cret") == true,
                "masking returns a copy; the original keeps the credential")
    }

    @Test("masking a text replaces each credentialed source and nothing else")
    func masksText() {
        let configuration = ProjectConfiguration(
            project: .init(name: "MyApp", bundleIdentifier: "com.example.myapp"),
            interface: .init(primary: .swiftUI),
            dependencyManagement: .init(mode: .cocoapods, cocoapods: .init(
                sources: ["https://ci:s3cret@example.com/specs.git"],
                pods: []
            ))
        )
        let text = """
        sources:
          - https://ci:s3cret@example.com/specs.git
        name: MyApp
        """

        let shown = CredentialMasking.masked(text, for: configuration)

        #expect(!shown.contains("s3cret"))
        #expect(shown.contains("https://***@example.com/specs.git"))
        #expect(shown.contains("name: MyApp"))
    }
}
