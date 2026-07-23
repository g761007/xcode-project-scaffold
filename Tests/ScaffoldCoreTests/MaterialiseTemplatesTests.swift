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

    @Test(
        "write a project per variant",
        .enabled(if: root != nil, "set MATERIALISE_ROOT to enable"),
        arguments: [UIFramework.uiKit, .swiftUI]
    )
    func write(interface: UIFramework) throws {
        let root = try #require(Self.root)
        let name = interface == .uiKit ? "UIKitApp" : "SwiftUIApp"
        let destination = URL(fileURLWithPath: root).appendingPathComponent(name)

        let plan = try GenerationPlanBuilder().makePlan(for: .validBaseline.with {
            $0.project.name = name
            $0.project.bundleIdentifier = "com.example.\(name.lowercased())"
            $0.interface = .init(primary: interface)
        })

        for file in plan.files {
            let url = destination.appendingPathComponent(file.path)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try file.contents.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
