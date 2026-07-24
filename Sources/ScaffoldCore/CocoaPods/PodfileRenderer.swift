import ScaffoldSchema

/// Renders the `Podfile` for a configuration whose mode reads pods (§9.3).
///
/// xscaffold writes the Podfile; the lock file and the workspace stay with
/// CocoaPods itself — generating either would be inventing what `pod install`
/// is about to compute. Pods go to the app target: the schema maps SPM
/// products to targets because packages carry several, but a pod is one thing
/// with one destination in this version.
struct PodfileRenderer: Sendable {
    func render(_ configuration: ProjectConfiguration) -> String {
        let pods = configuration.dependencyManagement.cocoapods?.pods ?? []
        let podLines = pods.flatMap(lines(for:)).map { "  \($0)" }

        return """
        platform :\(platformName(configuration.product.platform)), '\(configuration.product.deploymentTarget)'

        target '\(configuration.project.name)' do
          use_frameworks!

        \(podLines.joined(separator: "\n"))
        end

        """
    }

    /// One line per subspec, the Podfile way — `pod 'Name/Core'` — and the
    /// bare pod when none are named. The source spelling is shared, so a
    /// subspec cannot pin differently from its siblings.
    private func lines(for pod: Pod) -> [String] {
        let names = pod.subspecs.isEmpty ? [pod.name] : pod.subspecs.map { "\(pod.name)/\($0)" }
        return names.map { name in "pod '\(name)'\(sourceSuffix(for: pod.source))" }
    }

    private func sourceSuffix(for source: PodSource) -> String {
        switch source {
        case let .version(version):
            ", '\(version)'"
        case let .gitTag(url, tag):
            ", :git => '\(url)', :tag => '\(tag)'"
        case let .gitBranch(url, branch):
            ", :git => '\(url)', :branch => '\(branch)'"
        case let .gitCommit(url, commit):
            ", :git => '\(url)', :commit => '\(commit)'"
        case let .path(path):
            ", :path => '\(path)'"
        }
    }

    /// CocoaPods' own platform names (`:macos` since CocoaPods 1.1).
    private func platformName(_ platform: ApplePlatform) -> String {
        switch platform {
        case .iOS: "ios"
        case .macOS: "macos"
        }
    }
}
