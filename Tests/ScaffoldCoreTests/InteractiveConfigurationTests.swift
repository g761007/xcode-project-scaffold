@testable import ScaffoldCore
import ScaffoldSchema
import Testing

/// The collection `new` drives. Every case answers through a `ScriptedPrompter`,
/// so this is the whole interactive path minus the terminal — which is exactly
/// what the seam exists to make testable.
///
/// Answers are consumed in question order: name, bundle identifier, interface,
/// architecture, [example], environments; the choice questions take a number.
@Suite("Collecting answers interactively")
struct InteractiveConfigurationTests {
    @Test("a full set of answers becomes the configuration they describe")
    func happyPath() throws {
        let prompter = ScriptedPrompter([
            "Bookshelf", // name
            "com.acme.bookshelf", // bundle identifier
            "2", // interface: SwiftUI
            "2", // architecture: MVVM
            "y", // include the example
            "1" // environments: none
        ])

        let answers = try InteractiveConfiguration().collect(name: nil, using: prompter)

        #expect(answers.name == "Bookshelf")
        #expect(answers.bundleIdentifier == "com.acme.bookshelf")
        #expect(answers.interface == .swiftUI)
        #expect(answers.pattern == .mvvm)
        #expect(answers.includeExample == true)
        #expect(answers.environments.isEmpty)
    }

    @Test("questions are asked in their documented order")
    func order() throws {
        let prompter = ScriptedPrompter(["App", "", "1", "2", "y", "2"])

        _ = try InteractiveConfiguration().collect(name: nil, using: prompter)

        let order = [
            "Project name", "Bundle identifier", "Interface",
            "Architecture", "Include the example", "Build environments"
        ]
        let indices = order.map { prompter.firstIndex(of: $0) }
        #expect(indices.allSatisfy { $0 != nil })
        #expect(indices == indices.sorted { ($0 ?? -1) < ($1 ?? -1) })
    }

    @Test("a name given on the command line is not asked for")
    func nameFromArgument() throws {
        let prompter = ScriptedPrompter([
            "", // bundle identifier: accept the derived default
            "1", // interface: UIKit
            "1", // architecture: Minimal
            "2" // environments: standard
        ])

        let answers = try InteractiveConfiguration().collect(name: "Bookshelf", using: prompter)

        #expect(answers.name == "Bookshelf")
        #expect(prompter.firstIndex(of: "Project name") == nil)
        // An empty answer takes the derived default.
        #expect(answers.bundleIdentifier == "com.example.bookshelf")
        #expect(answers.environments == PartialProjectConfiguration.standardEnvironments)
    }

    @Test("the example is asked about only for a pattern that has one")
    func exampleOnlyWhereThereIsOne() throws {
        let minimal = ScriptedPrompter(["App", "", "1", "1", "1"])
        let minimalAnswers = try InteractiveConfiguration().collect(name: nil, using: minimal)
        #expect(minimalAnswers.includeExample == nil)
        #expect(minimal.firstIndex(of: "Include the example") == nil)

        let mvvm = ScriptedPrompter(["App", "", "1", "2", "n", "1"])
        let mvvmAnswers = try InteractiveConfiguration().collect(name: nil, using: mvvm)
        #expect(mvvmAnswers.includeExample == false)
        #expect(mvvm.firstIndex(of: "Include the example") != nil)
    }

    @Test("a free-text answer the validator rejects is asked again")
    func reasksInvalidField() throws {
        let prompter = ScriptedPrompter([
            "App", // name
            "nope", // bundle identifier: not reverse-DNS (XS1301)
            "1", // interface
            "1", // architecture: Minimal
            "1", // environments
            "com.acme.app" // asked again, now valid
        ])

        let answers = try InteractiveConfiguration().collect(name: nil, using: prompter)

        #expect(answers.bundleIdentifier == "com.acme.app")
        // The question carries a "[default]:"; the rejection message does not, so
        // this counts the times it was asked, not the once it was refused.
        #expect(prompter.timesAsked("Bundle identifier [") == 2)
    }

    /// The one combination the prompt lets a user reach that the validator
    /// rejects: MVVM-C on SwiftUI (XS0009). The prompt holds no rule about it —
    /// it offers the choice, then re-asks the architecture when validation says
    /// no.
    @Test("MVVM-C on SwiftUI is refused, then the architecture is asked again")
    func reasksIncompatibleArchitecture() throws {
        let prompter = ScriptedPrompter([
            "App", // name
            "", // bundle identifier: default
            "2", // interface: SwiftUI
            "3", // architecture: MVVM-C  (invalid on SwiftUI)
            "y", // include the example (MVVM-C has one, so it is asked)
            "1", // environments
            "2", // asked again: MVVM
            "y" // include the example
        ])

        let answers = try InteractiveConfiguration().collect(name: nil, using: prompter)

        #expect(answers.interface == .swiftUI)
        #expect(answers.pattern == .mvvm)
        #expect(prompter.timesAsked("Architecture") == 2)
    }

    @Test("input that ends before the answers are complete cancels")
    func endedInputCancels() {
        // The name is given, so the bundle identifier is the first question —
        // and there is nothing to answer it with.
        let prompter = ScriptedPrompter([])

        #expect(throws: InteractivePromptError.cancelled) {
            try InteractiveConfiguration().collect(name: "App", using: prompter)
        }
    }
}
