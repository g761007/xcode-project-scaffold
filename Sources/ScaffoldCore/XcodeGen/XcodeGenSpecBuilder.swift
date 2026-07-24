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
    static let uiTestSourceDirectories = ["UITests"]
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
            packages: makePackages(for: project),
            appTarget: makeAppTarget(for: project),
            testTarget: makeTestTarget(for: project),
            uiTestTarget: makeUITestTarget(for: project),
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
    /// XcodeGen needs each configuration marked debug or release. Exactly one of
    /// them is the unoptimised build; everything else is optimised.
    private func makeConfigurations(for project: ProjectConfiguration) -> [XcodeGenSpec.Configuration] {
        let debugName = debugConfigurationName(for: project)

        return project.environments.map { environment in
            XcodeGenSpec.Configuration(
                name: environment.configuration,
                optimized: environment.configuration != debugName
            )
        }
    }

    /// Which configuration is built without optimisation: `Debug` when an
    /// environment uses that name, and otherwise the first, because a project
    /// where everything is optimised cannot be debugged at all — a worse
    /// outcome than guessing.
    ///
    /// Asked by the configuration list and by every scheme's test action, so
    /// the rule is stated once. Two tellings of it would let a project mark one
    /// configuration as its debug build and run its tests against another.
    private func debugConfigurationName(for project: ProjectConfiguration) -> String {
        guard let first = project.environments.first else { return Self.debugConfigurationName }

        let usesConventionalName = project.environments.contains {
            $0.configuration == Self.debugConfigurationName
        }
        return usesConventionalName ? Self.debugConfigurationName : first.configuration
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
            overrides: makeOverrides(for: project),
            packageProducts: packageProducts(for: project.project.name, in: project)
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
            sources: Self.testSourceDirectories,
            packageProducts: packageProducts(for: "\(project.project.name)Tests", in: project)
        )
    }

    private func makeUITestTarget(for project: ProjectConfiguration) -> XcodeGenSpec.UITestTarget? {
        guard project.testing.ui.enabled else { return nil }

        return XcodeGenSpec.UITestTarget(
            name: "\(project.project.name)UITests",
            sources: Self.uiTestSourceDirectories
        )
    }
}

// MARK: - Packages

extension XcodeGenSpecBuilder {
    /// Whether this configuration's packages reach the project file: only the
    /// modes that read the spm section do (§9). The cocoapods half of `mixed`
    /// is Podfile territory, not project.yml's.
    private func usesPackages(_ project: ProjectConfiguration) -> Bool {
        project.dependencyManagement.mode == .spm || project.dependencyManagement.mode == .mixed
    }

    private func makePackages(for project: ProjectConfiguration) -> [XcodeGenSpec.Package] {
        guard usesPackages(project) else { return [] }

        return (project.dependencyManagement.spm?.packages ?? []).map { package in
            let requirement: (key: String, value: String) = switch package.requirement {
            case let .from(version): ("from", version)
            case let .exact(version): ("exactVersion", version)
            case let .branch(name): ("branch", name)
            case let .revision(hash): ("revision", hash)
            }
            return XcodeGenSpec.Package(
                name: package.name,
                url: package.url,
                requirementKey: requirement.key,
                requirementValue: requirement.value
            )
        }
    }

    /// The products a target links, in package declaration order — validation
    /// has already confirmed every named target exists.
    private func packageProducts(
        for target: String,
        in project: ProjectConfiguration
    ) -> [XcodeGenSpec.PackageProductDependency] {
        guard usesPackages(project) else { return [] }

        return (project.dependencyManagement.spm?.packages ?? []).flatMap { package in
            package.products
                .filter { $0.targets.contains(target) }
                .map { XcodeGenSpec.PackageProductDependency(packageName: package.name, productName: $0.name) }
        }
    }
}

// MARK: - Schemes

extension XcodeGenSpecBuilder {
    private func makeSchemes(for project: ProjectConfiguration) -> [XcodeGenSpec.Scheme] {
        let testConfiguration = debugConfigurationName(for: project)

        guard !project.environments.isEmpty else {
            return [XcodeGenSpec.Scheme(
                name: project.project.name,
                runConfiguration: Self.debugConfigurationName,
                testConfiguration: testConfiguration,
                archiveConfiguration: Self.releaseConfigurationName
            )]
        }

        return project.environments.map { environment in
            XcodeGenSpec.Scheme(
                name: schemeName(for: environment, in: project),
                runConfiguration: environment.configuration,
                testConfiguration: testConfiguration,
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
