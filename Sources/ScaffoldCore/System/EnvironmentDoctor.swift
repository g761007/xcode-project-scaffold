import Foundation
import ScaffoldSchema

/// Answers "will `init` work on this machine, and will the project it makes?"
///
/// This is the one place allowed to look at the machine. Validation is pure by
/// design — the same `scaffold.yml` must validate identically everywhere — so
/// every question whose answer depends on what is installed belongs here
/// instead.
public struct EnvironmentDoctor: Sendable {
    private let processRunner: any ProcessRunner

    public init(processRunner: any ProcessRunner = SystemProcessRunner()) {
        self.processRunner = processRunner
    }

    /// The configuration decides how hard to insist on the CocoaPods tools:
    /// with Bundler, `bundle` is required and provides pod itself; without,
    /// `pod` is. Everything else is the same on every machine.
    public func check(for configuration: ProjectConfiguration? = nil) -> [EnvironmentCheck] {
        tools(for: configuration).map(check)
    }

    /// Which tools matter, and which of them this configuration cannot do
    /// without. Separate from checking them because not every caller wants the
    /// versions: finding one is a `locate`, and reporting its version is a
    /// subprocess per tool.
    private func tools(for configuration: ProjectConfiguration?) -> [Tool] {
        let usesPods = configuration.map {
            $0.dependencyManagement.mode == .cocoapods || $0.dependencyManagement.mode == .mixed
        } ?? false
        let usesBundler = configuration?.dependencyManagement.cocoapods?.bundler?.enabled == true

        return Tool.all + [
            Tool.pod(required: usesPods && !usesBundler),
            Tool.bundle(required: usesPods && usesBundler)
        ]
    }

    /// The tools a plan is about to call and this machine does not have.
    ///
    /// Read off the plan's commands rather than off the configuration, because
    /// the configuration cannot know what this run will skip: `--skip-generate`
    /// means no generator is called, and warning about a missing one would be
    /// telling the truth about the machine and a lie about the run. What the
    /// plan lists is exactly what will be executed.
    ///
    /// The configuration still decides *which* CocoaPods tool matters — with
    /// Bundler it is `bundle`, without it `pod` — which is why it arrives here
    /// rather than that rule being written a second time.
    ///
    /// Only `locate` is asked, never `--version`. This runs while the preview
    /// is being drawn, before the user has chosen anything, and a preview that
    /// spawned a subprocess per known tool to render one warning line would be
    /// paying for an answer it does not use — a tool that is missing has no
    /// version to report.
    public func missingTools(
        calledBy plan: GenerationPlan,
        for configuration: ProjectConfiguration
    ) -> [EnvironmentCheck] {
        let called = Set(plan.commands.map(\.executable))
        return tools(for: configuration)
            .filter { called.contains($0.name) && processRunner.locate($0.name) == nil }
            .map { EnvironmentCheck(name: $0.name, required: $0.required, found: false, detail: $0.purpose) }
    }

    private func check(_ tool: Tool) -> EnvironmentCheck {
        guard processRunner.locate(tool.name) != nil else {
            return EnvironmentCheck(name: tool.name, required: tool.required, found: false, detail: tool.purpose)
        }

        return EnvironmentCheck(
            name: tool.name,
            required: tool.required,
            found: true,
            detail: version(of: tool)
        )
    }

    /// The version rather than the path: two Xcodes or two XcodeGens on one
    /// machine is the usual reason a project generates differently than it did
    /// yesterday, and a path alone does not show that.
    private func version(of tool: Tool) -> String? {
        let result = try? processRunner.run(ProcessInvocation(
            executable: tool.name,
            arguments: tool.versionArguments,
            workingDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        ))

        guard let result, result.succeeded else { return nil }
        let text = result.standardOutput.isEmpty ? result.standardError : result.standardOutput
        return text.split(separator: "\n").first.map { String($0).trimmingCharacters(in: .whitespaces) }
    }
}

extension EnvironmentDoctor {
    private struct Tool {
        let name: String
        let versionArguments: [String]
        /// Whether a default `init` fails without it.
        let required: Bool
        /// Shown when it is missing, because "xcodegen: not found" does not tell
        /// someone who has never heard of XcodeGen what to do.
        let purpose: String

        /// Optional tools are reported too: a project that generates but cannot
        /// be linted is better found out about here than by the first
        /// `make lint`.
        static let all: [Tool] = [
            Tool(
                name: "git",
                versionArguments: ["--version"],
                required: true,
                purpose: "Needed to create the project's repository. Pass --skip-git to do without."
            ),
            Tool(
                name: "xcodegen",
                versionArguments: ["--version"],
                required: true,
                purpose: "Produces the .xcodeproj. Install with `brew install xcodegen`, "
                    + "or pass --skip-generate."
            ),
            // Not required: §10.1 says `init` does not build by default, so a
            // machine without it can still generate a project. It is needed the
            // moment anyone runs `make build`, `make test` or --validate-build.
            Tool(
                name: "xcodebuild",
                versionArguments: ["-version"],
                required: false,
                purpose: "Comes with Xcode. Needed by `make build` and `make test` in a generated "
                    + "project, and by --validate-build."
            ),
            Tool(
                name: "swiftformat",
                versionArguments: ["--version"],
                required: false,
                purpose: "Needed by `make lint` and `make format` in a generated project. "
                    + "Install with `brew install swiftformat`."
            ),
            Tool(
                name: "swiftlint",
                versionArguments: ["--version"],
                required: false,
                purpose: "Needed by `make lint` in a generated project. "
                    + "Install with `brew install swiftlint`."
            )
        ]

        /// Required exactly when the configuration in hand reads pods without
        /// Bundler (§9.3); with Bundler, `bundle exec` provides pod itself.
        static func pod(required: Bool) -> Tool {
            Tool(
                name: "pod",
                versionArguments: ["--version"],
                required: required,
                purpose: "Needed when dependencyManagement.mode is cocoapods or mixed. "
                    + "Install with `brew install cocoapods`."
            )
        }

        /// Required exactly when the configuration runs pods through Bundler
        /// (§11.4).
        static func bundle(required: Bool) -> Tool {
            Tool(
                name: "bundle",
                versionArguments: ["--version"],
                required: required,
                purpose: "Needed when cocoapods.bundler is enabled. "
                    + "Comes with Ruby; `gem install bundler` if missing."
            )
        }
    }
}

extension [EnvironmentCheck] {
    /// Whether `init` can run at all. An optional tool that is missing is worth
    /// reporting and not worth failing over.
    public var meetsRequirements: Bool {
        allSatisfy { !$0.required || $0.found }
    }
}

extension EnvironmentCheck {
    /// One line, said before anything is written, as distinct from the column
    /// `doctor` prints when it was asked.
    ///
    /// It carries the tool's `detail` because that is where the install command
    /// lives: "pod is not installed" leaves a reader exactly where they were,
    /// and the whole reason to say this early is to hand them the next step.
    public var warningLine: String {
        "\(name) is not installed.\(detail.map { " \($0)" } ?? "")"
    }
}
