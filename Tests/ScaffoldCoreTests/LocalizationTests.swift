import Foundation
@testable import ScaffoldCore
import ScaffoldSchema
import Testing
import Yams

private func makeConfiguration(localization: Localization? = nil) -> ProjectConfiguration {
    ProjectConfiguration(
        project: .init(name: "Bookshelf", bundleIdentifier: "com.example.bookshelf"),
        interface: .init(primary: .swiftUI),
        localization: localization
    )
}

private func planFiles(_ configuration: ProjectConfiguration) throws -> [String] {
    guard case let .valid(validated, _) = ConfigurationValidator().check(configuration) else {
        struct DidNotValidate: Error {}
        throw DidNotValidate()
    }
    return try GenerationPlanBuilder()
        .makePlan(for: validated, options: GenerationOptions(initializeGit: false, runGenerator: false))
        .files.map(\.path)
}

/// Issue #66: `localization` — the wire, the lproj structure, and project.yml.
@Suite("Localization")
struct LocalizationTests {
    @Test("the section decodes, and an omitted one means the development language alone")
    func wireFormat() throws {
        let coder = ConfigurationCoder()

        let stated = try coder.decode("""
        project:
          name: App
          bundleIdentifier: com.example.app
        interface:
          primary: swiftui
        localization:
          developmentLanguage: en
          languages: [en, zh-Hant]
        """)
        #expect(stated.localization == Localization(developmentLanguage: "en", languages: ["en", "zh-Hant"]))

        let omitted = try coder.decode("""
        project:
          name: App
          bundleIdentifier: com.example.app
        interface:
          primary: swiftui
        """)
        #expect(omitted.localization.developmentLanguage == "en")
        #expect(omitted.localization.languages.isEmpty)
    }

    @Test("each shipped language gets its lproj and strings file")
    func lprojFiles() throws {
        let files = try planFiles(makeConfiguration(
            localization: Localization(languages: ["en", "zh-Hant"])
        ))

        #expect(files.contains("Resources/en.lproj/Localizable.strings"))
        #expect(files.contains("Resources/zh-Hant.lproj/Localizable.strings"))
    }

    @Test("no languages means no lproj at all")
    func notLocalized() throws {
        let files = try planFiles(makeConfiguration())

        #expect(!files.contains { $0.contains(".lproj/") })
    }

    @Test("project.yml states the development language only when it says something")
    func developmentLanguageInProjectYML() throws {
        func options(_ configuration: ProjectConfiguration) throws -> [String: Any] {
            let yaml = try XcodeGenSpecEncoder().encode(XcodeGenSpecBuilder().makeSpec(for: configuration))
            let document = try #require(Yams.load(yaml: yaml) as? [String: Any])
            return try #require(document["options"] as? [String: Any])
        }

        let localized = try options(makeConfiguration(
            localization: Localization(languages: ["en", "zh-Hant"])
        ))
        #expect(localized["developmentLanguage"] as? String == "en")

        let nonDefault = try options(makeConfiguration(
            localization: Localization(developmentLanguage: "ja")
        ))
        #expect(nonDefault["developmentLanguage"] as? String == "ja")

        let plain = try options(makeConfiguration())
        #expect(plain["developmentLanguage"] == nil, "an untouched project.yml stays untouched")
    }
}
