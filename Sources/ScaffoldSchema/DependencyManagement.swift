/// How the generated project takes its dependencies (§9): not at all, Swift
/// Package Manager, CocoaPods, or both at once. SPM is the default
/// recommendation (§3.4); CocoaPods exists for the teams that need it.
public enum DependencyMode: String, ScaffoldEnum {
    /// Named `disabled` rather than `none` to stay unambiguous against
    /// `Optional.none` at the call site. The wire format is still `none`.
    case disabled = "none"
    case spm
    case cocoapods
    case mixed
}

/// The `dependencyManagement` section of `scaffold.yml`.
///
/// `mode` decides which of the other sections is read at all: `none` loads
/// nothing, and declaring packages or pods under it is a validation error
/// rather than a silent ignore — a declaration that does nothing is a bug
/// waiting to be found later.
public struct DependencyManagement: Codable, Equatable, Sendable {
    public var mode: DependencyMode
    public var spm: SwiftPackageDependencies?
    public var cocoapods: CocoaPodsDependencies?

    public init(
        mode: DependencyMode? = nil,
        spm: SwiftPackageDependencies? = nil,
        cocoapods: CocoaPodsDependencies? = nil
    ) {
        self.mode = mode ?? ConfigurationDefaults.dependencyMode
        self.spm = spm
        self.cocoapods = cocoapods
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            mode: container.decodeIfPresent(DependencyMode.self, forKey: .mode),
            spm: container.decodeIfPresent(SwiftPackageDependencies.self, forKey: .spm),
            cocoapods: container.decodeIfPresent(CocoaPodsDependencies.self, forKey: .cocoapods)
        )
    }
}

// MARK: - Swift Package Manager

public struct SwiftPackageDependencies: Codable, Equatable, Sendable {
    public var packages: [SwiftPackage]

    public init(packages: [SwiftPackage]? = nil) {
        self.packages = packages ?? []
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(packages: container.decodeIfPresent([SwiftPackage].self, forKey: .packages))
    }
}

/// One remote package: where it lives, which versions are acceptable, and
/// which of its products go to which targets. Package name and product names
/// are modelled apart — a package is not its products.
public struct SwiftPackage: Codable, Equatable, Sendable {
    public var name: String
    public var url: String
    public var requirement: PackageRequirement
    public var products: [PackageProduct]

    public init(name: String, url: String, requirement: PackageRequirement, products: [PackageProduct]) {
        self.name = name
        self.url = url
        self.requirement = requirement
        self.products = products
    }

    /// The requirement is written inline — `from: "5.9.0"`, `exact:`,
    /// `branch:` or `revision:` — the way SwiftPM's own manifest reads.
    /// Exactly one must be present; zero is a package pinned to nothing, two
    /// is a contradiction, and both are refused at decode.
    enum CodingKeys: String, CodingKey {
        case name, url, products
        case from, exact, branch, revision
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        url = try container.decode(String.self, forKey: .url)
        products = try container.decodeIfPresent([PackageProduct].self, forKey: .products) ?? []
        requirement = try PackageRequirement(from: container)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(url, forKey: .url)
        try requirement.encode(into: &container)
        try container.encode(products, forKey: .products)
    }
}

/// Which versions of a package are acceptable — SwiftPM's four ways, one of
/// which must be chosen.
public enum PackageRequirement: Equatable, Sendable {
    case from(String)
    case exact(String)
    case branch(String)
    case revision(String)

    init(from container: KeyedDecodingContainer<SwiftPackage.CodingKeys>) throws {
        var found: [(SwiftPackage.CodingKeys, String)] = []
        for key: SwiftPackage.CodingKeys in [.from, .exact, .branch, .revision] {
            if let value = try container.decodeIfPresent(String.self, forKey: key) {
                found.append((key, value))
            }
        }

        guard found.count == 1, let (key, value) = found.first else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "A package states exactly one of 'from', 'exact', 'branch' or "
                    + "'revision'; this one states \(found.count)."
            ))
        }

        switch key {
        case .from: self = .from(value)
        case .exact: self = .exact(value)
        case .branch: self = .branch(value)
        case .revision: self = .revision(value)
        default: fatalError("unreachable: key came from the list above")
        }
    }

    func encode(into container: inout KeyedEncodingContainer<SwiftPackage.CodingKeys>) throws {
        switch self {
        case let .from(value): try container.encode(value, forKey: .from)
        case let .exact(value): try container.encode(value, forKey: .exact)
        case let .branch(value): try container.encode(value, forKey: .branch)
        case let .revision(value): try container.encode(value, forKey: .revision)
        }
    }
}

/// One product of a package, and the targets that link it.
public struct PackageProduct: Codable, Equatable, Sendable {
    public var name: String
    public var targets: [String]

    public init(name: String, targets: [String]) {
        self.name = name
        self.targets = targets
    }
}

// MARK: - CocoaPods

public struct CocoaPodsDependencies: Codable, Equatable, Sendable {
    public var pods: [Pod]
    /// Decoded now, acted on in v0.6 (§27): declaring it early keeps the
    /// schema stable, and the validator says "not yet" rather than the decoder
    /// saying "never heard of it".
    public var bundler: Bundler?

    public init(pods: [Pod]? = nil, bundler: Bundler? = nil) {
        self.pods = pods ?? []
        self.bundler = bundler
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            pods: container.decodeIfPresent([Pod].self, forKey: .pods),
            bundler: container.decodeIfPresent(Bundler.self, forKey: .bundler)
        )
    }

    public struct Bundler: Codable, Equatable, Sendable {
        public var enabled: Bool

        public init(enabled: Bool) {
            self.enabled = enabled
        }
    }
}

/// One pod: its name, where it comes from, and optionally which subspecs.
public struct Pod: Codable, Equatable, Sendable {
    public var name: String
    public var source: PodSource
    public var subspecs: [String]

    public init(name: String, source: PodSource, subspecs: [String] = []) {
        self.name = name
        self.source = source
        self.subspecs = subspecs
    }

    /// The source is written inline, Podfile-style: `version:`, `path:`, or
    /// `git:` with exactly one of `tag:`, `branch:` or `commit:`.
    enum CodingKeys: String, CodingKey {
        case name, subspecs
        case version, git, tag, branch, commit, path
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        subspecs = try container.decodeIfPresent([String].self, forKey: .subspecs) ?? []
        source = try PodSource(from: container)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try source.encode(into: &container)
        if !subspecs.isEmpty {
            try container.encode(subspecs, forKey: .subspecs)
        }
    }
}

/// Where a pod comes from — the five ways this version accepts (§9.3).
public enum PodSource: Equatable, Sendable {
    case version(String)
    case gitTag(url: String, tag: String)
    case gitBranch(url: String, branch: String)
    case gitCommit(url: String, commit: String)
    case path(String)

    init(from container: KeyedDecodingContainer<Pod.CodingKeys>) throws {
        let version = try container.decodeIfPresent(String.self, forKey: .version)
        let git = try container.decodeIfPresent(String.self, forKey: .git)
        let tag = try container.decodeIfPresent(String.self, forKey: .tag)
        let branch = try container.decodeIfPresent(String.self, forKey: .branch)
        let commit = try container.decodeIfPresent(String.self, forKey: .commit)
        let path = try container.decodeIfPresent(String.self, forKey: .path)

        func refuse(_ why: String) -> DecodingError {
            DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: container.codingPath,
                debugDescription: why
            ))
        }

        switch (version, git, tag, branch, commit, path) {
        case let (pinned?, nil, nil, nil, nil, nil):
            self = .version(pinned)
        case let (nil, url?, tagged?, nil, nil, nil):
            self = .gitTag(url: url, tag: tagged)
        case let (nil, url?, nil, branched?, nil, nil):
            self = .gitBranch(url: url, branch: branched)
        case let (nil, url?, nil, nil, pinned?, nil):
            self = .gitCommit(url: url, commit: pinned)
        case let (nil, nil, nil, nil, nil, local?):
            self = .path(local)
        case (nil, _?, nil, nil, nil, nil):
            throw refuse("A git pod states exactly one of 'tag', 'branch' or 'commit'.")
        default:
            throw refuse("A pod states exactly one source: 'version', 'path', or 'git' with one of "
                + "'tag', 'branch' or 'commit'.")
        }
    }

    func encode(into container: inout KeyedEncodingContainer<Pod.CodingKeys>) throws {
        switch self {
        case let .version(value):
            try container.encode(value, forKey: .version)
        case let .gitTag(url, tag):
            try container.encode(url, forKey: .git)
            try container.encode(tag, forKey: .tag)
        case let .gitBranch(url, branch):
            try container.encode(url, forKey: .git)
            try container.encode(branch, forKey: .branch)
        case let .gitCommit(url, commit):
            try container.encode(url, forKey: .git)
            try container.encode(commit, forKey: .commit)
        case let .path(value):
            try container.encode(value, forKey: .path)
        }
    }
}
