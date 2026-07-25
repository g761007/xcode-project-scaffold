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
        let usesPods = configuration.map {
            $0.dependencyManagement.mode == .cocoapods || $0.dependencyManagement.mode == .mixed
        } ?? false
        let usesBundler = configuration?.dependencyManagement.cocoapods?.bundler?.enabled == true

        return (Tool.all + [
            Tool.pod(required: usesPods && !usesBundler),
            Tool.bundle(required: usesPods && usesBundler)
        ]).map(check)
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
