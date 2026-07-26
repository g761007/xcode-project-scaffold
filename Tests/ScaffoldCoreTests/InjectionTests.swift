import Foundation
@testable import ScaffoldCore
import ScaffoldSchema
import Testing

/// The surface a security review of this tool has to look at: it takes user
/// input, renders it into code and configuration files, and then executes an
/// external command over the result. Every case here was written from a payload
/// that worked before the fix beside it.
@Suite("What a hostile scaffold.yml cannot do")
struct InjectionTests {
    // MARK: - Control characters

    /// The payload: one reviewed YAML line producing two build settings.
    ///
    ///     values:
    ///       API_BASE_URL: "https://x\nOTHER_LDFLAGS = -whatever"
    ///
    /// An xcconfig is `KEY = value` per line, so the newline ended the value
    /// and started a setting nobody wrote.
    @Test("a newline in an environment value is refused")
    func newlineInEnvironmentValue() {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.environments = [Environment(
                name: "development",
                configuration: "Debug",
                values: ["API_BASE_URL": "https://x\nOTHER_LDFLAGS = -whatever"]
            )]
        }

        let issue = codes(configuration).first { $0 == .controlCharacterInValue }
        #expect(issue != nil)
    }

    @Test("a newline in a secret's example is refused")
    func newlineInSecretExample() {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.secrets = Secrets(keys: [.init(name: "API_KEY", example: "fake\nOTHER = leaked")])
        }

        #expect(codes(configuration).contains(.controlCharacterInValue))
    }

    /// Checked over the whole document rather than field by field, so a field
    /// nobody thought about is covered too. `organizationName` is free text and
    /// reaches generated files; nothing had ever constrained it.
    @Test("a control character anywhere in the document is refused", arguments: [
        "project.organizationName",
        "environments[0].displayNameSuffix",
        "dependencyManagement.cocoapods.pods[0].name"
    ])
    func controlCharacterAnywhere(path: String) {
        var configuration = ProjectConfiguration.validBaseline
        switch path {
        case "project.organizationName":
            configuration.project.organizationName = "Acme\nEvil"
        case "environments[0].displayNameSuffix":
            configuration.environments = [Environment(
                name: "development", configuration: "Debug", displayNameSuffix: " Dev\nEvil"
            )]
        default:
            configuration.dependencyManagement = DependencyManagement(
                mode: .cocoapods,
                cocoapods: .init(pods: [Pod(name: "A\nB", source: .version("1.0"))])
            )
        }

        let issues = ConfigurationValidator().validate(configuration)
            .filter { $0.code == .controlCharacterInValue }

        #expect(issues.map(\.path) == [path])
    }

    /// The message has to be readable in a terminal, which means the newline it
    /// is reporting must not be *in* it.
    @Test("the refusal shows the control character rather than printing it")
    func messageEscapesTheCharacter() {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.project.organizationName = "Acme\nEvil"
        }

        let issue = ConfigurationValidator().validate(configuration)
            .first { $0.code == .controlCharacterInValue }

        #expect(issue?.message.contains("\\n") == true)
        #expect(issue?.message.contains("\n") == false)
    }

    @Test("an ordinary document has nothing to refuse")
    func cleanDocumentPasses() {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.project.organizationName = "O'Reilly & Associates, Inc."
            $0.environments = [Environment(
                name: "development",
                configuration: "Debug",
                displayNameSuffix: " Dev",
                values: ["API_BASE_URL": "https://dev.example.com/path?a=b&c=d"]
            )]
        }

        #expect(!codes(configuration).contains(.controlCharacterInValue))
    }

    // MARK: - The Podfile is Ruby, and xscaffold runs it

    /// The payload that needs no newline, and so survives the rule above:
    ///
    ///     pod 'a' + system('id') + '', '1.0'
    ///
    /// is valid Ruby. A Podfile is executed by `pod install`, which xscaffold
    /// runs itself immediately after generating it — so an unescaped value is
    /// arbitrary code execution on whoever generates from the document.
    @Test("a quote in a pod name cannot leave its Ruby literal")
    func quoteInPodName() {
        let podfile = PodfileRenderer().render(
            ProjectConfiguration.validBaseline.with {
                $0.dependencyManagement = DependencyManagement(
                    mode: .cocoapods,
                    cocoapods: .init(pods: [Pod(name: "a' + system('id') + '", source: .version("1.0"))])
                )
            }
        )

        #expect(podfile.contains(#"pod 'a\' + system(\'id\') + \''"#))
        #expect(!podfile.contains("pod 'a' + system"))
    }

    @Test("a quote in a source URL cannot leave its Ruby literal")
    func quoteInSource() {
        let podfile = PodfileRenderer().render(
            ProjectConfiguration.validBaseline.with {
                $0.dependencyManagement = DependencyManagement(
                    mode: .cocoapods,
                    cocoapods: .init(
                        sources: ["https://example.com/' ; system('id') ; x='"],
                        pods: [Pod(name: "SnapKit", source: .version("5.7.1"))]
                    )
                )
            }
        )

        #expect(!podfile.contains("; system('id')"))
        #expect(podfile.contains(#"\' ; system(\'id\')"#))
    }

    /// A backslash is the other character Ruby reads inside a single-quoted
    /// literal, and escaping only the quote would let one escape the escape.
    @Test("a backslash cannot escape the escaping")
    func backslashInPodName() {
        let podfile = PodfileRenderer().render(
            ProjectConfiguration.validBaseline.with {
                $0.dependencyManagement = DependencyManagement(
                    mode: .cocoapods,
                    cocoapods: .init(pods: [Pod(name: #"a\' + system('id') + '"#, source: .version("1.0"))])
                )
            }
        )

        #expect(podfile.contains(#"pod 'a\\\' + system(\'id\') + \''"#))
    }

    /// The Gemfile is Ruby too, and the pinned version reaches it the same way.
    @Test("a quote in the pinned CocoaPods version cannot leave its literal")
    func quoteInBundlerVersion() {
        let gemfile = GemfileRenderer().render(
            ProjectConfiguration.validBaseline.with {
                $0.dependencyManagement = DependencyManagement(
                    mode: .cocoapods,
                    cocoapods: .init(
                        pods: [Pod(name: "SnapKit", source: .version("5.7.1"))],
                        bundler: .init(enabled: true, cocoapodsVersion: "1.0' ; system('id') ; x='")
                    )
                )
            }
        )

        #expect(!gemfile.contains("; system('id')"))
        #expect(gemfile.contains(#"\' ; system(\'id\')"#))
    }

    // MARK: - Credentials, on the channels v0.8 added

    /// Masking predates the error object, so the question a review has to ask
    /// is whether the new channel inherited it. It does, because the error's
    /// message is the same `description` the text form prints — but the next
    /// output channel added should have to answer this again.
    @Test("a credential in a source URL is masked wherever a failure reports it")
    func credentialsAreMaskedInFailures() {
        let configuration = ProjectConfiguration.validBaseline.with {
            $0.dependencyManagement = DependencyManagement(
                mode: .cocoapods,
                cocoapods: .init(
                    sources: ["https://user:s3cr3t@internal.example.com/specs.git"],
                    pods: [Pod(name: "InternalKit", source: .version("1.0"))]
                )
            )
        }

        let command = PlannedCommand(executable: "pod", arguments: ["install"], purpose: "Install pods")
        let failure = GenerationError.commandFailed(
            command,
            exitStatus: 1,
            output: "Unable to reach https://user:s3cr3t@internal.example.com/specs.git"
        )
        let reported = CredentialMasking.masked(failure.scaffoldError.message, for: configuration)

        #expect(!reported.contains("s3cr3t"))
        #expect(reported.contains("***@internal.example.com"))
    }

    /// The Podfile is the one place the real URL has to survive: it is what
    /// CocoaPods authenticates with.
    @Test("the Podfile keeps the credential the masking hides everywhere else")
    func podfileKeepsTheRealURL() {
        let podfile = PodfileRenderer().render(
            ProjectConfiguration.validBaseline.with {
                $0.dependencyManagement = DependencyManagement(
                    mode: .cocoapods,
                    cocoapods: .init(
                        sources: ["https://user:s3cr3t@internal.example.com/specs.git"],
                        pods: [Pod(name: "InternalKit", source: .version("1.0"))]
                    )
                )
            }
        )

        #expect(podfile.contains("s3cr3t"))
    }

    // MARK: - No shell, anywhere

    /// The property the whole review rests on. A command is an executable and
    /// an argument array, and `SystemProcessRunner` hands both to `Process` —
    /// no shell parses anything, so a metacharacter is an ordinary character.
    ///
    /// Demonstrated rather than described: a destination path full of
    /// characters a shell would act on arrives at the runner byte for byte,
    /// and every argument the plan wrote is the argument the runner received.
    @Test("nothing a shell would act on is ever re-parsed")
    func metacharactersReachTheChildVerbatim() throws {
        // No slash: a path component cannot contain one, and validation
        // refuses a project name that does. Everything else a shell would act
        // on is here.
        let hostile = "App; rm -rf ~ && echo $(whoami) `id` | cat > out"
        let runner = FakeProcessRunner()

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("xscaffold-injection-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        do {
            let destination = root.appendingPathComponent(hostile)
            let plan = try GenerationPlanBuilder().makePlan(
                for: .validBaseline,
                options: GenerationOptions(initializeGit: true, runGenerator: true)
            )
            try PlanExecutor(processRunner: runner).execute(plan, at: destination)

            #expect(!runner.invocations.isEmpty)
            for invocation in runner.invocations {
                #expect(invocation.workingDirectory.lastPathComponent == hostile)
                #expect(!invocation.executable.contains(" "), "an executable is a name, not a line")
            }

            // Every argument survives as written — nothing was joined into a
            // string and split again, which is what a shell would have done.
            let commit = try #require(runner.invocations.first { $0.arguments.contains("commit") })
            #expect(commit.arguments == ["commit", "--message", "Initial commit"])
        }
    }
}
