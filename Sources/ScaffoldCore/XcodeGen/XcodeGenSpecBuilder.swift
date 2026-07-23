import ScaffoldSchema

/// Turns a validated `ProjectConfiguration` into the XcodeGen spec that
/// describes it. A pure function: same configuration, same spec.
struct XcodeGenSpecBuilder: Sendable {
    /// The name Xcode gives its unoptimised build configuration.
    ///
    /// The schema does not record which configurations are debug builds, and a
    /// field for it would make every user declare something they almost never
    /// vary. A project that needs a second debug configuration edits
    /// `project.yml`, which describes it from then on (ADR-0001).
    static let debugConfigurationName = "Debug"

    /// The name Xcode gives its optimised build configuration.
    static let releaseConfigurationName = "Release"

    static let appSourceDirectories = ["App", "Resources"]
    static let testSourceDirectories = ["Tests"]
    static let infoPlistPath = "App/Info.plist"

    func makeSpec(for project: ProjectConfiguration) -> XcodeGenSpec {
        let schemes = makeSchemes(for: project)

        return XcodeGenSpec(
            name: project.project.name,
            platform: xcodeGenPlatform(project.product.platform),
            deploymentTarget: project.product.deploymentTarget,
            languageMode: project.language.languageMode.rawValue,
            strictConcurrency: project.language.languageMode == .v6,
            configurations: makeConfigurations(for: project),
            appTarget: makeAppTarget(for: project),
            testTarget: makeTestTarget(for: project),
            schemes: schemes,
            // The bare-named scheme when there is one, which is the same rule
            // `schemeName(for:in:)` applies; otherwise simply the first.
            defaultSchemeName: schemes.first { $0.name == project.project.name }?.name
                ?? schemes[0].name
        )
    }
}

// MARK: - Configurations

extension XcodeGenSpecBuilder {
    /// XcodeGen needs each configuration marked debug or release. `Debug` is
    /// the debug one; everything else is optimised.
    ///
    /// If no environment uses that name the first one becomes the debug build,
    /// because a project where every configuration is optimised cannot be
    /// debugged at all — a worse outcome than guessing.
    private func makeConfigurations(for project: ProjectConfiguration) -> [XcodeGenSpec.Configuration] {
        let environments = project.environments
        let hasConventionalDebug = environments.contains { $0.configuration == Self.debugConfigurationName }

        return environments.enumerated().map { index, environment in
            let isDebug = hasConventionalDebug
                ? environment.configuration == Self.debugConfigurationName
                : index == 0
            return XcodeGenSpec.Configuration(name: environment.configuration, optimized: !isDebug)
        }
    }
}

// MARK: - Targets

extension XcodeGenSpecBuilder {
    private func makeAppTarget(for project: ProjectConfiguration) -> XcodeGenSpec.AppTarget {
        let isIOS = project.product.platform == .iOS

        return XcodeGenSpec.AppTarget(
            productType: xcodeGenProductType(project.product.type),
            bundleIdentifier: project.project.bundleIdentifier,
            displayName: project.project.name,
            sources: Self.appSourceDirectories,
            infoPlist: XcodeGenSpec.InfoPlist(
                path: Self.infoPlistPath,
                includesLaunchScreen: isIOS,
                includesSceneManifest: isIOS && project.interface.primary == .uiKit
            ),
            overrides: makeOverrides(for: project)
        )
    }

    /// Only environments that actually change something get an override — one
    /// that repeated the base values would be noise in the generated file.
    private func makeOverrides(for project: ProjectConfiguration) -> [XcodeGenSpec.TargetOverride] {
        project.environments.compactMap { environment in
            let bundleSuffix = environment.bundleIdentifierSuffix ?? ""
            let displaySuffix = environment.displayNameSuffix ?? ""
            guard !bundleSuffix.isEmpty || !displaySuffix.isEmpty else { return nil }

            return XcodeGenSpec.TargetOverride(
                configuration: environment.configuration,
                bundleIdentifier: project.project.bundleIdentifier + bundleSuffix,
                displayName: project.project.name + displaySuffix
            )
        }
    }

    private func makeTestTarget(for project: ProjectConfiguration) -> XcodeGenSpec.TestTarget? {
        guard project.testing.unit != .disabled else { return nil }

        return XcodeGenSpec.TestTarget(
            name: "\(project.project.name)Tests",
            sources: Self.testSourceDirectories
        )
    }
}

// MARK: - Schemes

extension XcodeGenSpecBuilder {
    private func makeSchemes(for project: ProjectConfiguration) -> [XcodeGenSpec.Scheme] {
        guard !project.environments.isEmpty else {
            return [XcodeGenSpec.Scheme(
                name: project.project.name,
                runConfiguration: Self.debugConfigurationName,
                archiveConfiguration: Self.releaseConfigurationName
            )]
        }

        return project.environments.map { environment in
            XcodeGenSpec.Scheme(
                name: schemeName(for: environment, in: project),
                runConfiguration: environment.configuration,
                archiveConfiguration: environment.configuration
            )
        }
    }

    /// The environment building `Release` keeps the bare project name: it is
    /// the scheme used to archive for the App Store, and the one Xcode selects
    /// when the project is first opened. Every other environment is suffixed.
    private func schemeName(for environment: Environment, in project: ProjectConfiguration) -> String {
        guard environment.configuration != Self.releaseConfigurationName else {
            return project.project.name
        }
        return "\(project.project.name)-\(titleCased(environment.name))"
    }

    /// `development` becomes `Development`. Unlike `String.capitalized` this
    /// leaves the rest of the name alone, so `iOSBeta` does not become
    /// `Iosbeta`. Deliberately not abbreviated to `Dev`: that needs a lookup
    /// table of everyone's preferred short forms, and there is no right answer
    /// for names it has never seen.
    private func titleCased(_ name: String) -> String {
        guard let first = name.first else { return name }
        return first.uppercased() + name.dropFirst()
    }
}

// MARK: - XcodeGen's vocabulary

extension XcodeGenSpecBuilder {
    /// XcodeGen spells its platforms `iOS` and `macOS`, not `ios` and `macos`.
    private func xcodeGenPlatform(_ platform: ApplePlatform) -> String {
        switch platform {
        case .iOS: "iOS"
        case .macOS: "macOS"
        }
    }

    private func xcodeGenProductType(_ type: ProductType) -> String {
        switch type {
        case .application: "application"
        case .framework: "framework"
        }
    }
}
