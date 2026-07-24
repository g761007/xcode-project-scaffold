@testable import ScaffoldCore
import ScaffoldSchema
import Testing
import Yams

// MARK: - Fixtures

private func makeConfiguration(
    mode: DependencyMode,
    packages: [SwiftPackage] = []
) -> ProjectConfiguration {
    ProjectConfiguration(
        project: .init(name: "MyApp", bundleIdentifier: "com.example.myapp"),
        interface: .init(primary: .swiftUI),
        dependencyManagement: .init(mode: mode, spm: .init(packages: packages))
    )
}

private let alamofire = SwiftPackage(
    name: "Alamofire",
    url: "https://github.com/Alamofire/Alamofire.git",
    requirement: .from("5.9.0"),
    products: [PackageProduct(name: "Alamofire", targets: ["MyApp"])]
)

/// Issue #62: packages reach `project.yml` through the spec — requirements
/// translated to XcodeGen's own keys, products mapped to the targets that
/// asked for them, and nothing at all when the mode does not read them.
@Suite("Packages in the spec")
struct XcodeGenSpecPackageTests {
    let builder = XcodeGenSpecBuilder()

    @Test("the four requirements translate to XcodeGen's keys", arguments: [
        (PackageRequirement.from("5.9.0"), "from", "5.9.0"),
        (.exact("1.2.3"), "exactVersion", "1.2.3"),
        (.branch("main"), "branch", "main"),
        (.revision("abc123"), "revision", "abc123")
    ])
    func requirementKeys(requirement: PackageRequirement, key: String, value: String) {
        let configuration = makeConfiguration(mode: .spm, packages: [
            SwiftPackage(name: "Dep", url: "https://example.com/dep.git", requirement: requirement, products: [])
        ])

        let package = builder.makeSpec(for: configuration).packages.first

        #expect(package?.requirementKey == key)
        #expect(package?.requirementValue == value)
    }

    @Test("products land on the targets that asked for them")
    func productMapping() {
        let shared = SwiftPackage(
            name: "Collections",
            url: "https://example.com/collections.git",
            requirement: .from("1.1.0"),
            products: [PackageProduct(name: "Collections", targets: ["MyApp", "MyAppTests"])]
        )

        let spec = builder.makeSpec(for: makeConfiguration(mode: .spm, packages: [alamofire, shared]))

        #expect(spec.appTarget.packageProducts == [
            .init(packageName: "Alamofire", productName: "Alamofire"),
            .init(packageName: "Collections", productName: "Collections")
        ])
        #expect(spec.testTarget?.packageProducts == [
            .init(packageName: "Collections", productName: "Collections")
        ])
    }

    @Test("mode none carries no packages even if some are declared")
    func disabledModeIgnoresPackages() {
        let spec = builder.makeSpec(for: makeConfiguration(mode: .disabled, packages: [alamofire]))

        #expect(spec.packages.isEmpty)
        #expect(spec.appTarget.packageProducts.isEmpty)
    }
}

/// The emitted `project.yml`, parsed back: what XcodeGen will actually read.
@Suite("Packages in the emitted project.yml")
struct EmittedPackageTests {
    private func parse(_ configuration: ProjectConfiguration) throws -> [String: Any] {
        let yaml = try XcodeGenSpecEncoder().encode(XcodeGenSpecBuilder().makeSpec(for: configuration))
        return try #require(Yams.load(yaml: yaml) as? [String: Any])
    }

    @Test("the packages section names the url and the requirement")
    func packagesSection() throws {
        let document = try parse(makeConfiguration(mode: .spm, packages: [alamofire]))

        let packages = try #require(document["packages"] as? [String: Any])
        let entry = try #require(packages["Alamofire"] as? [String: Any])
        #expect(entry["url"] as? String == "https://github.com/Alamofire/Alamofire.git")
        #expect(entry["from"] as? String == "5.9.0")
    }

    @Test("the app target lists the product as a dependency")
    func appTargetDependency() throws {
        let document = try parse(makeConfiguration(mode: .spm, packages: [alamofire]))

        let targets = try #require(document["targets"] as? [String: Any])
        let app = try #require(targets["MyApp"] as? [String: Any])
        let dependencies = try #require(app["dependencies"] as? [[String: Any]])
        #expect(dependencies.contains {
            $0["package"] as? String == "Alamofire" && $0["product"] as? String == "Alamofire"
        })
    }

    @Test("the test target keeps its app dependency alongside package products")
    func testTargetDependencies() throws {
        let shared = SwiftPackage(
            name: "Collections",
            url: "https://example.com/collections.git",
            requirement: .from("1.1.0"),
            products: [PackageProduct(name: "Collections", targets: ["MyAppTests"])]
        )
        let document = try parse(makeConfiguration(mode: .spm, packages: [shared]))

        let targets = try #require(document["targets"] as? [String: Any])
        let tests = try #require(targets["MyAppTests"] as? [String: Any])
        let dependencies = try #require(tests["dependencies"] as? [[String: Any]])
        #expect(dependencies.first?["target"] as? String == "MyApp")
        #expect(dependencies.contains { $0["package"] as? String == "Collections" })
    }

    @Test("no packages means no packages section and no dependencies key")
    func absentWithoutPackages() throws {
        let document = try parse(makeConfiguration(mode: .disabled))

        #expect(document["packages"] == nil)
        let targets = try #require(document["targets"] as? [String: Any])
        let app = try #require(targets["MyApp"] as? [String: Any])
        #expect(app["dependencies"] == nil)
    }
}
