@testable import ScaffoldCore
import ScaffoldSchema
import Testing

/// `capabilities` is what an agent reads instead of guessing (§19), which makes
/// every list in it a promise. Seven of the eight are sourced from the type
/// that enforces them and cannot be wrong. `features` is the eighth: there is
/// no `Feature` type, so nothing but this suite notices when it stops being
/// true.
@Suite("What capabilities advertises")
struct CapabilitiesTests {
    private let capabilities = CapabilitiesDocument.current(version: "0.9.0")

    /// The list as it is frozen. Written out rather than derived, because a
    /// golden that computes itself agrees with any change to what it pins.
    @Test("features is the list it was frozen at")
    func featuresAreFrozen() {
        #expect(capabilities.features == [
            "environments",
            "github-actions",
            "localization",
            "notification-service",
            "secrets",
            "ui-tests",
            "widget"
        ])
    }

    /// The failure this prevents: a third App Extension is added — the kinds
    /// table exists so that it is one entry rather than a copy of the machinery
    /// — and the project generates it while `capabilities` says it cannot. An
    /// agent would then never write the section that turns it on.
    @Test("every extension this binary generates is one it advertises")
    func everyExtensionKindIsAdvertised() {
        for kind in AppExtensionKind.all {
            #expect(capabilities.features.contains(kind.featureName), "\(kind.directoryName)")
        }
    }

    /// The name is the provider's own, so `ci.provider: github-actions` in a
    /// document and `github-actions` in this list are the same string rather
    /// than two spellings that have to be kept in step.
    @Test("the CI feature is spelled the way a document spells it")
    func ciFeatureMatchesTheProvider() {
        #expect(capabilities.features.contains(CIProvider.gitHubActions.rawValue))
    }

    /// A vocabulary rule, so the next entry does not arrive as
    /// `notificationService` beside `notification-service`. Every other list in
    /// this document is kebab-case because its type's raw values are.
    @Test("every feature is named the way the rest of the wire is")
    func featureNamesAreKebabCase() {
        for feature in capabilities.features {
            #expect(feature.wholeMatch(of: /[a-z][a-z0-9]*(-[a-z0-9]+)*/) != nil, "\(feature)")
        }
    }
}
