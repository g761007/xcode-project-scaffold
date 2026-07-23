@testable import ScaffoldCore
import Testing

private let renderer = TemplateRenderer()

@Suite("Rendering templates")
struct TemplateRendererTests {
    @Test("a placeholder is replaced by its value")
    func substitutes() throws {
        let rendered = try renderer.render(
            "struct {{PROJECT_NAME}}App {}",
            path: "App.swift",
            with: ["PROJECT_NAME": "MyApp"]
        )

        #expect(rendered == "struct MyAppApp {}")
    }

    @Test("the same placeholder is replaced everywhere it appears")
    func substitutesRepeatedly() throws {
        let rendered = try renderer.render(
            "{{NAME}} and {{NAME}} again",
            path: "x",
            with: ["NAME": "A"]
        )

        #expect(rendered == "A and A again")
    }

    @Test("text with no placeholders is returned unchanged")
    func passesThrough() throws {
        #expect(try renderer.render("nothing here", path: "x", with: [:]) == "nothing here")
    }

    /// Leaving the placeholder in place would usually still compile —
    /// placeholders sit in comments and string literals too — so the mistake
    /// would surface as a puzzling generated project rather than as an error.
    @Test("an unknown placeholder is an error, not a silent pass-through")
    func unknownPlaceholderThrows() throws {
        let error = #expect(throws: TemplateRenderingError.self) {
            try renderer.render("{{MYSTERY}}", path: "App/Thing.swift", with: ["OTHER": "x"])
        }

        #expect(error?.placeholder == "MYSTERY")
        #expect(error?.templatePath == "App/Thing.swift")
        #expect(error?.message == "App/Thing.swift uses {{MYSTERY}}, which has no value.")
    }

    /// Single braces turn up all over generated files — the Makefile's
    /// `${...}`, JSON, Swift bodies — and must pass through untouched.
    @Test("single braces are ordinary text", arguments: [
        "a { b } c", "func f() { }", "${SHELL_VAR}", "}} before {"
    ])
    func singleBracesAreLiteral(text: String) throws {
        #expect(try renderer.render(text, path: "x", with: [:]) == text)
    }

    /// `{{` with nothing closing it is a typo far more often than it is
    /// intentional, and passing it through would put it in the generated file.
    @Test("an unterminated placeholder is an error")
    func unterminatedThrows() throws {
        let error = #expect(throws: TemplateRenderingError.self) {
            try renderer.render("{{ unclosed", path: "App/Thing.swift", with: [:])
        }

        #expect(error?.reason == .unterminated)
        #expect(error?.message == "App/Thing.swift has an unterminated {{ with no closing }}.")
    }

    /// Reported apart from "no value" so the message says what is actually
    /// wrong: `{{{{X}}}}` would otherwise complain that `{{X` has no value.
    @Test("a name that cannot be a placeholder is reported as malformed", arguments: [
        "{{{{X}}}}", "{{ X }}", "{{lowercase}}", "{{}}", "{{A-B}}"
    ])
    func malformedNameThrows(text: String) throws {
        let error = #expect(throws: TemplateRenderingError.self) {
            try renderer.render(text, path: "x", with: ["X": "v"])
        }

        #expect(error?.reason == .malformedName)
    }

    @Test("placeholders in a path are replaced too")
    func rendersPaths() throws {
        let rendered = try renderer.render(
            "App/{{PROJECT_NAME}}App.swift",
            path: "App/{{PROJECT_NAME}}App.swift",
            with: ["PROJECT_NAME": "MyApp"]
        )

        #expect(rendered == "App/MyAppApp.swift")
    }
}
