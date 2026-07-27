@testable import ScaffoldCore
import ScaffoldSchema
import Testing

/// The seventh question, and the flag that answers it without asking (#160).
///
/// The mode is the one answer that chooses which resolved preset the others are
/// laid over, because `production` normalizes differently for a mode that reads
/// pods. So these assert both halves: that the question collects what it should,
/// and that what it collects picks the right base.
@Suite("Asking which dependency manager")
struct InteractiveDependencyModeTests {
    /// Seven answers now, and the seventh is the mode. Empty takes the default,
    /// which is what the preset — here, none — suggests.
    @Test("the question is asked, and its answer is what the run uses",
          arguments: [(2, DependencyMode.spm), (3, .cocoapods), (4, .mixed), (1, .disabled)])
    func theQuestionIsAsked(answer: Int, expected: DependencyMode) throws {
        let prompter = ScriptedPrompter(["1", "Bookshelf", "", "2", "2", "y", "1", "\(answer)"])

        let answers = try InteractiveConfiguration().collect(name: nil, using: prompter)

        #expect(answers.dependencyMode == expected)
        #expect(answers.resolved().dependencyManagement.mode == expected)
    }

    /// The regression guard for adding a question at all: a run that presses
    /// return through it has to land exactly where it landed before.
    @Test("pressing return takes what the preset suggests",
          arguments: [(Preset.minimal, DependencyMode.disabled), (.standard, .spm), (.production, .spm)])
    func returnTakesThePresetSuggestion(preset: Preset, expected: DependencyMode) throws {
        let prompter = ScriptedPrompter(["1", "Bookshelf", "", "2", "2", "y", "1", ""])
        let bases = try PresetBases(preset: preset)

        let answers = try InteractiveConfiguration(presetBases: bases).collect(name: nil, using: prompter)

        #expect(answers.dependencyMode == expected)
        #expect(bases.configuration(for: answers).dependencyManagement.mode == expected)
    }

    /// The strongest form of "adding a question changed nothing": the answers a
    /// return-pressing run produces have to describe the same dependencies as
    /// the route that never asks — `--yes --variant`, which builds its document
    /// straight from the preset.
    @Test("pressing return describes the same dependencies as the route that never asks",
          arguments: [Preset.minimal, .standard, .production])
    func returnMatchesTheUnaskedRoute(preset: Preset) throws {
        let prompter = ScriptedPrompter(["1", "Bookshelf", "", "2", "2", "y", "1", ""])
        let bases = try PresetBases(preset: preset)

        let asked = try InteractiveConfiguration(presetBases: bases)
            .collect(name: nil, using: prompter)
        let unasked = try Variant.iOSSwiftUI.configuration(projectName: "Bookshelf", preset: preset)

        #expect(bases.configuration(for: asked).dependencyManagement == unasked.dependencyManagement)
    }

    /// The offered default is shown the way `freeText` shows one, so that
    /// pressing return is visibly a choice rather than a guess.
    @Test("the question shows which mode return would take")
    func theDefaultIsShown() throws {
        let prompter = ScriptedPrompter(["1", "Bookshelf", "", "2", "2", "y", "1", ""])

        let bases = try PresetBases(preset: .standard)

        _ = try InteractiveConfiguration(presetBases: bases).collect(name: nil, using: prompter)

        #expect(prompter.shown.contains("Dependency manager [Swift Package Manager]:"))
    }

    /// Stated on the command line, the question is not asked — the same
    /// relationship `--variant` has with platform and interface. Six answers
    /// here, not seven: a seventh would be consumed by nothing.
    @Test("a stated mode answers the question and it is not asked")
    func aStatedModeSkipsTheQuestion() throws {
        let prompter = ScriptedPrompter(["1", "Bookshelf", "", "2", "2", "y", "1"])

        let answers = try InteractiveConfiguration()
            .collect(name: nil, dependencyMode: .cocoapods, using: prompter)

        #expect(answers.dependencyMode == .cocoapods)
        #expect(prompter.timesAsked("Dependency manager") == 0)
    }

    /// The whole reason the base is resolved per mode: an answer of `cocoapods`
    /// under `production` has to land on the document that pins Bundler, and
    /// `spm` on the one that does not.
    @Test("the answer chooses which resolved preset the run lands on")
    func theAnswerChoosesTheBase() throws {
        let bases = try PresetBases(preset: .production)

        let pods = try InteractiveConfiguration(presetBases: bases).collect(
            name: nil, using: prompter(answering: "3")
        )
        let packages = try InteractiveConfiguration(presetBases: bases).collect(
            name: nil, using: prompter(answering: "2")
        )

        let withPods = bases.configuration(for: pods)
        let withPackages = bases.configuration(for: packages)

        #expect(withPods.dependencyManagement.mode == .cocoapods)
        #expect(withPods.dependencyManagement.cocoapods?.bundler?.enabled == true)
        #expect(withPods.dependencyManagement.cocoapods?.bundler?.cocoapodsVersion != nil)

        #expect(withPackages.dependencyManagement.mode == .spm)
        #expect(withPackages.dependencyManagement.cocoapods?.bundler == nil)
    }

    private func prompter(answering mode: String) -> ScriptedPrompter {
        ScriptedPrompter(["1", "Bookshelf", "", "2", "2", "y", "1", mode])
    }
}

/// The preset resolved once per dependency mode (#160).
@Suite("Resolving a preset for every mode")
struct PresetBasesTests {
    /// Normalization is what makes these four documents different from each
    /// other rather than four copies with one field changed.
    @Test("production pins Bundler for the modes that read pods, and only those")
    func productionNormalizesPerMode() throws {
        let bases = try PresetBases(preset: .production)

        for mode in [DependencyMode.cocoapods, .mixed] {
            #expect(bases[mode]?.dependencyManagement.cocoapods?.bundler?.enabled == true)
        }
        for mode in [DependencyMode.disabled, .spm] {
            #expect(bases[mode]?.dependencyManagement.cocoapods?.bundler == nil)
        }
    }

    @Test("every mode resolves to a base stating that mode", arguments: DependencyMode.allCases)
    func everyModeResolves(mode: DependencyMode) throws {
        let bases = try PresetBases(preset: .standard)

        #expect(bases[mode]?.dependencyManagement.mode == mode)
    }

    /// No preset is not a missing answer: it asks for the schema's own
    /// defaults, which is what the answers apply on their own.
    @Test("no preset resolves to no base, and suggests the schema's default")
    func noPresetIsEmpty() throws {
        let bases = try PresetBases(preset: nil)

        #expect(bases.suggestedMode == ConfigurationDefaults.dependencyMode)
        for mode in DependencyMode.allCases {
            #expect(bases[mode] == nil)
        }
    }

    @Test("the suggestion is what the preset says with nothing stated",
          arguments: [(Preset.minimal, DependencyMode.disabled), (.standard, .spm), (.production, .spm)])
    func suggestionComesFromThePreset(preset: Preset, expected: DependencyMode) throws {
        #expect(try PresetBases(preset: preset).suggestedMode == expected)
    }
}
