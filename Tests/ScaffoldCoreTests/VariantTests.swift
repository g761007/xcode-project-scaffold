@testable import ScaffoldCore
import ScaffoldSchema
import Testing

/// A variant is the shortest path from nothing to a project, so the property
/// that matters is that it never needs a second step: whatever it produces must
/// already be valid and already have templates.
@Suite("Variants")
struct VariantTests {
    @Test("every variant produces a configuration that validates", arguments: Variant.all)
    func variantsValidate(variant: Variant) {
        let issues = ConfigurationValidator().validate(variant.configuration(projectName: "MyApp"))

        #expect(issues.isEmpty, "\(variant.name): \(issues.map(\.message))")
    }

    @Test("every variant produces a configuration that can be planned", arguments: Variant.all)
    func variantsPlan(variant: Variant) throws {
        let plan = try GenerationPlanBuilder().makePlan(for: variant.configuration(projectName: "MyApp"))

        #expect(plan.files.contains { $0.path == "project.yml" })
    }

    /// The two iOS variants exist to choose between UIKit and SwiftUI; if they
    /// stopped differing, `--variant` would be decoration.
    @Test("the iOS variants differ in their interface")
    func variantsDiffer() throws {
        let uiKit = try #require(Variant.named("ios-uikit"))
        let swiftUI = try #require(Variant.named("ios-swiftui"))

        #expect(uiKit.configuration(projectName: "MyApp").interface.primary == .uiKit)
        #expect(swiftUI.configuration(projectName: "MyApp").interface.primary == .swiftUI)
    }

    /// The macOS pair. The platform is what separates them from the iOS
    /// variants; the deployment target and lifecycle follow from it.
    @Test("the macOS variants target macOS on each interface")
    func macOSVariants() throws {
        let swiftUI = try #require(Variant.named("macos-swiftui")).configuration(projectName: "MyApp")
        let appKit = try #require(Variant.named("macos-appkit")).configuration(projectName: "MyApp")

        #expect(swiftUI.product.platform == .macOS)
        #expect(swiftUI.interface.primary == .swiftUI)
        #expect(appKit.product.platform == .macOS)
        #expect(appKit.interface.primary == .appKit)
    }

    @Test("an unknown name is not a variant")
    func unknownVariant() {
        #expect(Variant.named("ios-appkit") == nil)
    }

    /// The identifier is derived, not asked for, so it has to survive names that
    /// are not already reverse-DNS segments.
    @Test("the bundle identifier is derived from the project name", arguments: [
        ("MyApp", "com.example.myapp"),
        ("My App", "com.example.myapp"),
        ("Book-Shelf 2", "com.example.bookshelf2")
    ])
    func bundleIdentifier(projectName: String, expected: String) {
        #expect(Variant.bundleIdentifier(for: projectName) == expected)
    }
}
