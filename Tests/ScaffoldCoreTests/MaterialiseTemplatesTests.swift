import Foundation
@testable import ScaffoldCore
import ScaffoldSchema
import Testing

/// Writes each variant to disk so that the real toolchain can be pointed at it.
///
/// Templates that are merely rendered can still be malformed: `make lint` in a
/// freshly generated project failed on its own template sources until this
/// existed. Only a run of `swiftformat` and `swiftlint` over the generated
/// files catches that, and neither belongs in a unit test — so this writes the
/// files and CI does the checking.
///
/// Skipped unless `MATERIALISE_ROOT` is set, because a test suite should not
/// litter the file system by default.
@Suite("Materialising templates for external checks")
struct MaterialiseTemplatesTests {
    static let root = ProcessInfo.processInfo.environment["MATERIALISE_ROOT"]

    /// One generated project to lay on disk. The architecture example ships its
    /// own sources, so it needs a case of its own — the plain variants would
    /// never render `GreetingViewModel` for a linter to read.
    struct Variant: Sendable, CustomStringConvertible {
        let name: String
        let interface: UIFramework
        let architecture: ArchitecturePattern
        let includeExample: Bool?

        var description: String {
            name
        }
    }

    static let variants: [Variant] = [
        Variant(name: "UIKitApp", interface: .uiKit, architecture: .minimal, includeExample: nil),
        Variant(name: "SwiftUIApp", interface: .swiftUI, architecture: .minimal, includeExample: nil),
        Variant(name: "UIKitMVVMApp", interface: .uiKit, architecture: .mvvm, includeExample: true)
    ]

    @Test(
        "write a project per variant",
        .enabled(if: root != nil, "set MATERIALISE_ROOT to enable"),
        arguments: variants
    )
    func write(variant: Variant) throws {
        let root = try #require(Self.root)
        let destination = URL(fileURLWithPath: root).appendingPathComponent(variant.name)

        let plan = try GenerationPlanBuilder().makePlan(
            for: .validBaseline.with {
                $0.project.name = variant.name
                $0.project.bundleIdentifier = "com.example.\(variant.name.lowercased())"
                $0.interface = .init(primary: variant.interface)
                $0.architecture = .init(pattern: variant.architecture, includeExample: variant.includeExample)
            },
            // No commands, so nothing here needs git or XcodeGen: this exists to
            // put files where a linter can read them.
            options: GenerationOptions(initializeGit: false, runGenerator: false)
        )

        try PlanExecutor().execute(plan, at: destination)
    }
}
