import Foundation
import ScaffoldSchema

// The dependencyManagement checks (§9), apart only for file size: the same
// validator, the same two-group contract.

extension ConfigurationValidator {
    func dependencyIssues(_ configuration: ProjectConfiguration) -> [ValidationIssue] {
        let dependencies = configuration.dependencyManagement

        return modeMismatchIssues(dependencies)
            + packageIssues(dependencies, targets: expectedTargets(of: configuration))
            + podIssues(dependencies)
            + podSourceIssues(dependencies)
            + crossManagerIssues(dependencies)
    }

    /// A declaration the mode never reads is a bug waiting to be found later,
    /// not something to silently ignore.
    private func modeMismatchIssues(_ dependencies: DependencyManagement) -> [ValidationIssue] {
        let declaresPackages = dependencies.spm?.packages.isEmpty == false
        let declaresPods = dependencies.cocoapods?.pods.isEmpty == false
        let declaresSources = dependencies.cocoapods?.sources.isEmpty == false
        var issues: [ValidationIssue] = []

        func outside(_ what: String, at path: String) -> ValidationIssue {
            ValidationIssue(
                code: .dependenciesOutsideMode,
                message: "\(what) are declared, but dependencyManagement.mode "
                    + "'\(dependencies.mode.rawValue)' never reads them.",
                path: path,
                suggestion: "Change the mode, or remove the declaration."
            )
        }

        switch dependencies.mode {
        case .disabled:
            if declaresPackages {
                issues.append(outside("Packages", at: "dependencyManagement.spm"))
            }
            if declaresPods {
                issues.append(outside("Pods", at: "dependencyManagement.cocoapods"))
            }
            if declaresSources {
                issues.append(outside("Pod sources", at: "dependencyManagement.cocoapods.sources"))
            }
        case .spm:
            if declaresPods {
                issues.append(outside("Pods", at: "dependencyManagement.cocoapods"))
            }
            if declaresSources {
                issues.append(outside("Pod sources", at: "dependencyManagement.cocoapods.sources"))
            }
        case .cocoapods:
            if declaresPackages {
                issues.append(outside("Packages", at: "dependencyManagement.spm"))
            }
        case .mixed:
            break
        }
        return issues
    }

    /// The targets a generated project has, which is what a product mapping
    /// may name: the app target and its unit-test target.
    private func expectedTargets(of configuration: ProjectConfiguration) -> Set<String> {
        [configuration.project.name, "\(configuration.project.name)Tests"]
    }

    private func packageIssues(
        _ dependencies: DependencyManagement,
        targets: Set<String>
    ) -> [ValidationIssue] {
        let packages = dependencies.spm?.packages ?? []
        var issues: [ValidationIssue] = []

        issues += duplicates(packages.map(\.name), ignoringCase: true).map { index, name in
            ValidationIssue(
                code: .duplicatePackageName,
                message: "Package name '\(name)' is declared more than once.",
                path: "dependencyManagement.spm.packages[\(index)].name",
                suggestion: "Declare each package once; one declaration can map several products."
            )
        }

        issues += packages.enumerated().compactMap { index, package in
            guard package.url.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return ValidationIssue(
                code: .emptyPackageURL,
                message: "Package '\(package.name)' has an empty url.",
                path: "dependencyManagement.spm.packages[\(index)].url",
                suggestion: "State where the package lives, such as "
                    + "'https://github.com/Alamofire/Alamofire.git'."
            )
        }

        for (packageIndex, package) in packages.enumerated() {
            for (productIndex, product) in package.products.enumerated() {
                for target in product.targets where !targets.contains(target) {
                    issues.append(ValidationIssue(
                        code: .unknownProductTarget,
                        message: "Product '\(product.name)' maps to target '\(target)', "
                            + "which this project does not generate.",
                        path: "dependencyManagement.spm.packages[\(packageIndex)]"
                            + ".products[\(productIndex)].targets",
                        suggestion: "Use \(list(targets.map(\.self)))."
                    ))
                }
            }
        }

        return issues
    }

    private func podIssues(_ dependencies: DependencyManagement) -> [ValidationIssue] {
        duplicates((dependencies.cocoapods?.pods ?? []).map(\.name), ignoringCase: true)
            .map { index, name in
                ValidationIssue(
                    code: .duplicatePodName,
                    message: "Pod '\(name)' is declared more than once.",
                    path: "dependencyManagement.cocoapods.pods[\(index)].name",
                    suggestion: "Declare each pod once; use subspecs for its parts."
                )
            }
    }

    /// Source URLs may carry credentials, so every message spells them through
    /// `CredentialMasking` — the issue travels into logs and JSON documents,
    /// which is exactly where the token must not go (§11.4).
    private func podSourceIssues(_ dependencies: DependencyManagement) -> [ValidationIssue] {
        let sources = dependencies.cocoapods?.sources ?? []
        var issues: [ValidationIssue] = []

        issues += sources.enumerated().compactMap { index, source in
            guard source.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return ValidationIssue(
                code: .emptyPodSource,
                message: "A pod source is empty.",
                path: "dependencyManagement.cocoapods.sources[\(index)]",
                suggestion: "State the spec repository URL, such as 'https://cdn.cocoapods.org/'."
            )
        }

        issues += duplicates(sources, ignoringCase: true).map { index, source in
            ValidationIssue(
                code: .duplicatePodSource,
                message: "Pod source '\(CredentialMasking.masked(source))' is declared more than once.",
                path: "dependencyManagement.cocoapods.sources[\(index)]",
                suggestion: "List each spec repository once; the Podfile keeps the declared order."
            )
        }

        return issues
    }

    /// The same library arriving through both managers would be linked twice.
    /// Matched by name, case-insensitively — the one signal both sides share.
    private func crossManagerIssues(_ dependencies: DependencyManagement) -> [ValidationIssue] {
        guard dependencies.mode == .mixed else { return [] }
        let packageNames = Set((dependencies.spm?.packages ?? []).map { $0.name.lowercased() })

        return (dependencies.cocoapods?.pods ?? []).enumerated().compactMap { index, pod in
            guard packageNames.contains(pod.name.lowercased()) else { return nil }
            return ValidationIssue(
                code: .duplicateDependency,
                message: "'\(pod.name)' is declared as both a package and a pod; "
                    + "the project would link it twice.",
                path: "dependencyManagement.cocoapods.pods[\(index)].name",
                suggestion: "Keep it under one manager — SPM where both offer it."
            )
        }
    }
}
