@testable import ScaffoldCore
import ScaffoldSchema
import Testing

/// Issue #96: the `scaffold.yml` a person starts from and the one generation
/// records are one document. `config example` prints it; `generate` writes it
/// into the project, and neither may say something the other does not.
@Suite("The scaffold.yml this tool writes")
struct ScaffoldDocumentTests {
    private let document = ScaffoldDocument()

    /// The annotation is what makes an editor complete and check the file, so
    /// it has to be the first line rather than merely present.
    @Test("it opens with the schema annotation")
    func annotation() throws {
        let text = try document.text(for: .validBaseline)

        #expect(text.hasPrefix("# yaml-language-server: $schema=https://"))
        #expect(text.contains("Schemas/scaffold.schema.json\n"))
    }

    /// The example's whole promise: what it prints is what generation will read
    /// back. A document that decoded to something else would send someone off
    /// to edit a file that does not describe their project.
    @Test("a printed document decodes to the configuration it was printed from", arguments: Preset.allCases)
    func roundTrip(preset: Preset) throws {
        let configuration = try PresetResolution.baseConfiguration(for: preset)

        let decoded = try ConfigurationCoder().decode(document.text(for: configuration))

        #expect(decoded == configuration)
    }

    /// Resolving is idempotent, which is what lets a resolved document carry
    /// its `preset:` line: re-reading it applies the preset under fields that
    /// are all stated, so nothing moves.
    @Test("a printed document still names the preset it resolved", arguments: Preset.allCases)
    func presetIsRecorded(preset: Preset) throws {
        let text = try document.text(for: PresetResolution.baseConfiguration(for: preset))

        #expect(text.contains("preset: \(preset.rawValue)\n"))
    }

    /// The acceptance criterion in the ticket's own words: generating from the
    /// example gets the project `--preset` would have got. Asserted on the whole
    /// plan rather than on the configuration — every file's contents and every
    /// command, because two plans agreeing on paths and differing inside them
    /// would still be two different projects.
    @Test("generating from the example plans what the preset plans", arguments: Preset.allCases)
    func generatesTheSameProject(preset: Preset) throws {
        let resolved = try PresetResolution.baseConfiguration(for: preset)
        let fromExample = try ConfigurationCoder().decode(document.text(for: resolved))

        let planner = GenerationPlanBuilder()
        let fromDocument = try planner.makePlan(for: fromExample)
        let fromPreset = try planner.makePlan(for: resolved)

        #expect(fromDocument == fromPreset)
    }

    /// No preset is an answer, not a missing one — someone who wants the
    /// schema's own defaults gets a document that says so by saying nothing.
    @Test("an example with no preset names none")
    func noPreset() throws {
        let configuration = try PresetResolution.baseConfiguration(for: nil)
        let text = try document.text(for: configuration)

        #expect(configuration.preset == nil)
        #expect(!text.contains("preset:"))
    }

    /// The identity is the one thing an example cannot supply, so it has to be
    /// obviously a placeholder — and still valid, or the file could not be run
    /// through `validate` before being edited.
    @Test("the placeholder identity validates as it stands")
    func placeholderValidates() throws {
        let configuration = try PresetResolution.baseConfiguration(for: .production)

        #expect(configuration.project.name == Preset.placeholderName)
        guard case .valid = ConfigurationValidator().check(configuration) else {
            Issue.record("the example a user is told to edit does not validate")
            return
        }
    }

    /// The claim the shared type exists to make: the file generation records is
    /// the file the example prints, byte for byte.
    @Test("generate records the same document the example prints")
    func generateWritesTheSameDocument() throws {
        let configuration = try PresetResolution.baseConfiguration(for: .standard)
        let plan = try GenerationPlanBuilder().makePlan(for: configuration)

        let recorded = try #require(plan.files.first { $0.path == "scaffold.yml" })
        let printed = try document.text(for: configuration)

        #expect(recorded.contents == printed)
    }
}
