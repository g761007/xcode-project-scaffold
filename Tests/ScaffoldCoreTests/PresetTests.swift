@testable import ScaffoldCore
import ScaffoldSchema
import Testing

/// A preset is the shortest path from nothing to a project, so the property
/// that matters is that it never needs a second step: whatever it produces must
/// already be valid and already have templates.
@Suite("Presets")
struct PresetTests {
    @Test("every preset produces a configuration that validates", arguments: Preset.all)
    func presetsValidate(preset: Preset) {
        let issues = ConfigurationValidator().validate(preset.configuration(projectName: "MyApp"))

        #expect(issues.isEmpty, "\(preset.name): \(issues.map(\.message))")
    }

    @Test("every preset produces a configuration that can be planned", arguments: Preset.all)
    func presetsPlan(preset: Preset) throws {
        let plan = try GenerationPlanBuilder().makePlan(for: preset.configuration(projectName: "MyApp"))

        #expect(plan.files.contains { $0.path == "project.yml" })
    }

    /// The two presets exist to choose between UIKit and SwiftUI; if they
    /// stopped differing, `--preset` would be decoration.
    @Test("the presets differ in their interface")
    func presetsDiffer() throws {
        let uiKit = try #require(Preset.named("ios-uikit"))
        let swiftUI = try #require(Preset.named("ios-swiftui"))

        #expect(uiKit.configuration(projectName: "MyApp").interface.primary == .uiKit)
        #expect(swiftUI.configuration(projectName: "MyApp").interface.primary == .swiftUI)
    }

    /// M5 adds the macOS pair. The platform is what separates them from the iOS
    /// presets; the deployment target and lifecycle follow from it.
    @Test("the macOS presets target macOS on each interface")
    func macOSPresets() throws {
        let swiftUI = try #require(Preset.named("macos-swiftui")).configuration(projectName: "MyApp")
        let appKit = try #require(Preset.named("macos-appkit")).configuration(projectName: "MyApp")

        #expect(swiftUI.product.platform == .macOS)
        #expect(swiftUI.interface.primary == .swiftUI)
        #expect(appKit.product.platform == .macOS)
        #expect(appKit.interface.primary == .appKit)
    }

    @Test("an unknown name is not a preset")
    func unknownPreset() {
        #expect(Preset.named("ios-appkit") == nil)
    }

    /// The identifier is derived, not asked for, so it has to survive names that
    /// are not already reverse-DNS segments.
    @Test("the bundle identifier is derived from the project name", arguments: [
        ("MyApp", "com.example.myapp"),
        ("My App", "com.example.myapp"),
        ("Book-Shelf 2", "com.example.bookshelf2")
    ])
    func bundleIdentifier(projectName: String, expected: String) {
        #expect(Preset.bundleIdentifier(for: projectName) == expected)
    }
}
