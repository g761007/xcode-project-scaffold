@testable import ScaffoldCore
import ScaffoldSchema
import Testing

/// The `dependencyManagement` wire format (§9): the inline requirement and
/// pod-source spellings, their exactly-one rules, and the round trip.
@Suite("dependencyManagement wire contract")
struct DependencyYAMLTests {
    let coder = ConfigurationCoder()

    private func decode(_ dependencySection: String) throws -> ProjectConfiguration {
        try coder.decode("""
        project:
          name: MyApp
          bundleIdentifier: com.example.myapp
        interface:
          primary: swiftui
        dependencyManagement:
        \(dependencySection)
        """)
    }

    @Test("all four package requirements decode")
    func packageRequirementsDecode() throws {
        let configuration = try decode("""
          mode: spm
          spm:
            packages:
              - name: Alamofire
                url: https://github.com/Alamofire/Alamofire.git
                from: "5.9.0"
                products:
                  - name: Alamofire
                    targets: [MyApp]
              - name: Exact
                url: https://example.com/exact.git
                exact: "1.2.3"
              - name: Branch
                url: https://example.com/branch.git
                branch: main
              - name: Revision
                url: https://example.com/revision.git
                revision: abc123
        """)

        let dependencies = configuration.dependencyManagement
        #expect(dependencies.mode == .spm)
        #expect(dependencies.spm?.packages.map(\.requirement)
            == [.from("5.9.0"), .exact("1.2.3"), .branch("main"), .revision("abc123")])
        #expect(dependencies.spm?.packages.first?.products
            == [PackageProduct(name: "Alamofire", targets: ["MyApp"])])
    }

    @Test("all five pod sources decode, with subspecs and bundler")
    func podSourcesDecode() throws {
        let configuration = try decode("""
          mode: cocoapods
          cocoapods:
            pods:
              - name: SnapKit
                version: "5.7.0"
              - name: Tagged
                git: https://example.com/tagged.git
                tag: v1.0.0
              - name: Branched
                git: https://example.com/branched.git
                branch: develop
              - name: Pinned
                git: https://example.com/pinned.git
                commit: deadbeef
              - name: Local
                path: ../Local
                subspecs: [Core, Extras]
            bundler:
              enabled: true
        """)

        let cocoapods = configuration.dependencyManagement.cocoapods
        #expect(cocoapods?.pods.map(\.source) == [
            .version("5.7.0"),
            .gitTag(url: "https://example.com/tagged.git", tag: "v1.0.0"),
            .gitBranch(url: "https://example.com/branched.git", branch: "develop"),
            .gitCommit(url: "https://example.com/pinned.git", commit: "deadbeef"),
            .path("../Local")
        ])
        #expect(cocoapods?.pods.last?.subspecs == ["Core", "Extras"])
        #expect(cocoapods?.bundler?.enabled == true)
    }

    @Test("an omitted section means mode none")
    func omittedDefaultsToNone() throws {
        let configuration = try coder.decode("""
        project:
          name: MyApp
          bundleIdentifier: com.example.myapp
        interface:
          primary: swiftui
        """)

        #expect(configuration.dependencyManagement.mode == .disabled)
        #expect(configuration.dependencyManagement.spm == nil)
        #expect(configuration.dependencyManagement.cocoapods == nil)
    }

    @Test("a package with no requirement, or two, is refused at decode", arguments: [
        "", // none of the four
        "\n        exact: \"1.0.0\"" // a second one
    ])
    func packageRequirementIsExactlyOne(extra: String) throws {
        #expect(throws: ConfigurationParsingError.self) {
            _ = try decode("""
              mode: spm
              spm:
                packages:
                  - name: Broken
                    url: https://example.com/broken.git\(extra.isEmpty ? "" : "\n        from: \"2.0.0\"")\(extra)
            """)
        }
    }

    @Test("a pod source that is ambiguous or missing is refused at decode", arguments: [
        "", // nothing
        "\n        version: \"1.0\"\n        path: ../Local", // two sources
        "\n        git: https://example.com/x.git" // git without tag/branch/commit
    ])
    func podSourceIsExactlyOne(extra: String) throws {
        #expect(throws: ConfigurationParsingError.self) {
            _ = try decode("""
              mode: cocoapods
              cocoapods:
                pods:
                  - name: Broken\(extra)
            """)
        }
    }

    @Test("the section round-trips through encode and decode")
    func roundTrips() throws {
        let original = ProjectConfiguration(
            project: .init(name: "MyApp", bundleIdentifier: "com.example.myapp"),
            interface: .init(primary: .swiftUI),
            dependencyManagement: DependencyManagement(
                mode: .mixed,
                spm: .init(packages: [
                    SwiftPackage(
                        name: "Alamofire",
                        url: "https://github.com/Alamofire/Alamofire.git",
                        requirement: .from("5.9.0"),
                        products: [PackageProduct(name: "Alamofire", targets: ["MyApp"])]
                    )
                ]),
                cocoapods: .init(
                    pods: [Pod(name: "SnapKit", source: .version("5.7.0"), subspecs: ["Core"])],
                    bundler: .init(enabled: false)
                )
            )
        )

        let decoded = try coder.decode(coder.encode(original))

        #expect(decoded.dependencyManagement == original.dependencyManagement)
    }
}
