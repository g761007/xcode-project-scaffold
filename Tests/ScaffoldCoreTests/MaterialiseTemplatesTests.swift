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
    /// never render `GreetingViewModel` for a linter to read. The example is not
    /// stated: an unset value follows the pattern, so `mvvm` brings its example
    /// and `minimal` brings none — exactly what a real project gets.
    struct Variant: Sendable, CustomStringConvertible {
        let name: String
        let platform: ApplePlatform
        let interface: UIFramework
        let architecture: ArchitecturePattern

        var description: String {
            name
        }
    }

    static let variants: [Variant] = [
        Variant(name: "UIKitApp", platform: .iOS, interface: .uiKit, architecture: .minimal),
        Variant(name: "SwiftUIApp", platform: .iOS, interface: .swiftUI, architecture: .minimal),
        Variant(name: "UIKitMVVMApp", platform: .iOS, interface: .uiKit, architecture: .mvvm),
        Variant(name: "SwiftUIMVVMApp", platform: .iOS, interface: .swiftUI, architecture: .mvvm),
        Variant(name: "UIKitMVVMCApp", platform: .iOS, interface: .uiKit, architecture: .mvvmCoordinator),
        Variant(name: "MacSwiftUIApp", platform: .macOS, interface: .swiftUI, architecture: .minimal),
        Variant(name: "MacAppKitApp", platform: .macOS, interface: .appKit, architecture: .minimal),
        Variant(name: "MacSwiftUIMVVMApp", platform: .macOS, interface: .swiftUI, architecture: .mvvm),
        Variant(name: "MacAppKitMVVMApp", platform: .macOS, interface: .appKit, architecture: .mvvm)
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
                $0.product.platform = variant.platform
                $0.interface = .init(primary: variant.interface)
                $0.architecture = .init(pattern: variant.architecture)
            },
            // No commands, so nothing here needs git or XcodeGen: this exists to
            // put files where a linter can read them.
            options: GenerationOptions(initializeGit: false, runGenerator: false)
        )

        try PlanExecutor().execute(plan, at: destination)
    }
}
