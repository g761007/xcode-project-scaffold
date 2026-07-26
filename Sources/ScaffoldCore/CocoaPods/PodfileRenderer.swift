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
        let cocoapods = configuration.dependencyManagement.cocoapods
        let pods = cocoapods?.pods ?? []
        let podLines = pods.flatMap(lines(for:)).map { "  \($0)" }

        // Spec repositories head the file in declaration order (§11.4) — the
        // order CocoaPods searches them in. None declared writes no line: the
        // CDN default is CocoaPods' own, not something to restate.
        let sources = (cocoapods?.sources ?? []).map { "source '\(ruby: $0)'" }
        let sourceBlock = sources.isEmpty ? "" : sources.joined(separator: "\n") + "\n\n"

        return sourceBlock + """
        platform :\(platformName(configuration.product.platform)), '\(ruby: configuration.product.deploymentTarget)'

        target '\(ruby: configuration.project.name)' do
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
        return names.map { name in "pod '\(ruby: name)'\(sourceSuffix(for: pod.source))" }
    }

    private func sourceSuffix(for source: PodSource) -> String {
        switch source {
        case let .version(version):
            ", '\(ruby: version)'"
        case let .gitTag(url, tag):
            ", :git => '\(ruby: url)', :tag => '\(ruby: tag)'"
        case let .gitBranch(url, branch):
            ", :git => '\(ruby: url)', :branch => '\(ruby: branch)'"
        case let .gitCommit(url, commit):
            ", :git => '\(ruby: url)', :commit => '\(ruby: commit)'"
        case let .path(path):
            ", :path => '\(ruby: path)'"
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

/// Renders the Gemfile Bundler runs on (§11.4). One gem, optionally pinned:
/// the lock file is `bundle install`'s to write, the same division as the
/// Podfile and its lock.
struct GemfileRenderer: Sendable {
    func render(_ configuration: ProjectConfiguration) -> String {
        let pin = configuration.dependencyManagement.cocoapods?.bundler?.cocoapodsVersion
        let gemLine = pin.map { "gem 'cocoapods', '\(ruby: $0)'" } ?? "gem 'cocoapods'"

        return """
        source 'https://rubygems.org'

        \(gemLine)

        """
    }
}

extension DefaultStringInterpolation {
    /// A value going inside a Ruby single-quoted literal.
    ///
    /// A Podfile is Ruby, and `pod install` runs it — which xscaffold does
    /// itself, right after generation. An unescaped value therefore turns a
    /// `scaffold.yml` into arbitrary code execution on whoever generates from
    /// it: `name: "a' + system('id') + '"` needs no newline and no quoting
    /// trick beyond the one Ruby gives for free.
    ///
    /// Inside a single-quoted literal Ruby treats exactly two characters
    /// specially, so escaping exactly those two is complete rather than a
    /// blocklist that will be missing one.
    mutating func appendInterpolation(ruby value: String) {
        appendLiteral(
            value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
        )
    }
}
