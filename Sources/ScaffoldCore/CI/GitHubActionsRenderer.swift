import ScaffoldSchema

/// Renders the GitHub Actions workflows the `ci` section asks for (§21).
///
/// A Features-layer citizen: it adds its own files under `.github/workflows/`
/// and patches no other template. Each workflow rebuilds the project the way a
/// person would — XcodeGen first, then the dependency manager the mode reads,
/// then xcodebuild against the container `ProjectContainer` decides — so CI
/// and a laptop cannot come to different conclusions about what building means.
struct GitHubActionsRenderer: Sendable {
    /// The image this project's own CI runs on — the best evidence available
    /// of a runner that exists and carries current Xcode.
    private static let runner = "macos-26"

    /// One file per enabled switch. An omitted `ci` section returns nothing.
    func files(for configuration: ProjectConfiguration) -> [PlannedFile] {
        guard let ci = configuration.ci else { return [] }

        var files: [PlannedFile] = []
        if ci.workflows.build {
            files.append(PlannedFile(
                path: ".github/workflows/build.yml",
                contents: workflow(named: "Build", steps: xcodebuildSteps(.build, for: configuration),
                                   for: configuration)
            ))
        }
        if ci.workflows.test {
            files.append(PlannedFile(
                path: ".github/workflows/test.yml",
                contents: workflow(named: "Test", steps: xcodebuildSteps(.test, for: configuration),
                                   for: configuration)
            ))
        }
        if ci.workflows.lint {
            files.append(PlannedFile(
                path: ".github/workflows/lint.yml",
                contents: workflow(named: "Lint", steps: lintSteps(for: configuration), for: configuration)
            ))
        }
        return files
    }
}

// MARK: - Steps

private struct Step {
    var name: String
    var run: String
}

private enum XcodebuildAction: String {
    case build
    case test
}

extension GitHubActionsRenderer {
    /// Build and test share their shape: produce the project file, install
    /// what the dependency mode reads, then run xcodebuild — only the final
    /// action and its destination differ.
    private func xcodebuildSteps(
        _ action: XcodebuildAction,
        for configuration: ProjectConfiguration
    ) -> [Step] {
        [
            Step(name: "Install XcodeGen", run: "brew install xcodegen"),
            Step(name: "Generate the project", run: "xcodegen generate")
        ]
            + dependencySteps(for: configuration)
            + [xcodebuildStep(action, for: configuration)]
    }

    /// SPM resolves explicitly so a bad manifest fails on its own step (§21);
    /// pods install bare or through Bundler, exactly as generation ran them.
    /// Mixed takes the pod path — its packages resolve during the build.
    private func dependencySteps(for configuration: ProjectConfiguration) -> [Step] {
        switch configuration.dependencyManagement.mode {
        case .disabled:
            return []
        case .spm:
            return [Step(name: "Resolve Swift packages", run: "xcodebuild -resolvePackageDependencies")]
        case .cocoapods, .mixed:
            guard configuration.dependencyManagement.cocoapods?.bundler?.enabled == true else {
                return [Step(name: "Install Pods", run: "pod install")]
            }
            return [
                Step(name: "Install Ruby dependencies", run: "bundle install"),
                Step(name: "Install Pods", run: "bundle exec pod install")
            ]
        }
    }

    private func xcodebuildStep(
        _ action: XcodebuildAction,
        for configuration: ProjectConfiguration
    ) -> Step {
        let container = ProjectContainer(for: configuration)
        let scheme = XcodeGenSpecBuilder().makeSpec(for: configuration).defaultSchemeName

        return Step(
            name: action == .build ? "Build" : "Test",
            run: "xcodebuild \(action.rawValue) \(container.xcodebuildFlag) '\(container.fileName)' "
                + "-scheme '\(scheme)' "
                + destinationArguments(action, for: configuration.product.platform)
        )
    }

    /// The same destinations the rest of the tool uses: a generic simulator
    /// for building (no runtime needs to exist), a named one for testing —
    /// the generated Makefile's own default — and the host for macOS, with
    /// signing off because a runner holds no identity.
    private func destinationArguments(
        _ action: XcodebuildAction,
        for platform: ApplePlatform
    ) -> String {
        switch (platform, action) {
        case (.iOS, .build):
            "-destination 'generic/platform=iOS Simulator' -quiet"
        case (.iOS, .test):
            "-destination 'platform=iOS Simulator,name=iPhone 16'"
        case (.macOS, .build):
            "-destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -quiet"
        case (.macOS, .test):
            "-destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY=-"
        }
    }

    /// Lint runs the generated Makefile's own recipe, so the workflow and
    /// `make lint` cannot drift; only the enabled tools are installed first.
    private func lintSteps(for configuration: ProjectConfiguration) -> [Step] {
        var tools: [String] = []
        if configuration.quality.swiftformat {
            tools.append("swiftformat")
        }
        if configuration.quality.swiftlint {
            tools.append("swiftlint")
        }

        var steps: [Step] = []
        if !tools.isEmpty {
            steps.append(Step(name: "Install the linters", run: "brew install \(tools.joined(separator: " "))"))
        }
        steps.append(Step(name: "Lint", run: "make lint"))
        return steps
    }
}

// MARK: - The workflow skeleton

extension GitHubActionsRenderer {
    private func workflow(
        named name: String,
        steps: [Step],
        for configuration: ProjectConfiguration
    ) -> String {
        var lines = [
            "name: \(name)",
            "",
            "on:",
            "  push:",
            "    branches: [\(configuration.git.defaultBranch)]",
            "  pull_request:",
            "",
            "jobs:",
            "  \(name.lowercased()):",
            "    runs-on: \(Self.runner)",
            "    steps:",
            "      - uses: actions/checkout@v4"
        ]
        for step in steps {
            lines.append("      - name: \(step.name)")
            lines.append("        run: \(step.run)")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
