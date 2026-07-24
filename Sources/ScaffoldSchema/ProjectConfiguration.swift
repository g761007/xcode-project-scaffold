/// A complete description of the project to create, with every default already
/// resolved. The only input the generation pipeline accepts.
///
/// This describes the *project*, never a particular run. Whether to initialise
/// git, whether to invoke the generator, whether to overwrite — those are CLI
/// flags, because they are not properties of the project being described.
///
/// Optional initialiser parameters throughout mean "not stated". Each default
/// is applied in exactly one place, so the memberwise initialiser and the
/// decoder cannot drift apart.
public struct ProjectConfiguration: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var project: Project
    public var product: Product
    public var language: Language
    public var interface: Interface
    public var architecture: Architecture
    public var generator: Generator
    public var environments: [Environment]
    public var quality: Quality
    public var testing: Testing
    public var git: Git

    public init(
        schemaVersion: Int? = nil,
        project: Project,
        product: Product? = nil,
        language: Language? = nil,
        interface: Interface,
        architecture: Architecture? = nil,
        generator: Generator? = nil,
        environments: [Environment]? = nil,
        quality: Quality? = nil,
        testing: Testing? = nil,
        git: Git? = nil
    ) {
        self.schemaVersion = schemaVersion ?? ConfigurationDefaults.schemaVersion
        self.project = project
        self.product = product ?? Product()
        self.language = language ?? Language()
        self.interface = interface
        self.architecture = architecture ?? Architecture()
        self.generator = generator ?? Generator()
        self.environments = environments ?? []
        self.quality = quality ?? Quality()
        self.testing = testing ?? Testing()
        self.git = git ?? Git()
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decodeIfPresent(Int.self, forKey: .schemaVersion),
            project: container.decode(Project.self, forKey: .project),
            product: container.decodeIfPresent(Product.self, forKey: .product),
            language: container.decodeIfPresent(Language.self, forKey: .language),
            interface: container.decode(Interface.self, forKey: .interface),
            architecture: container.decodeIfPresent(Architecture.self, forKey: .architecture),
            generator: container.decodeIfPresent(Generator.self, forKey: .generator),
            environments: container.decodeIfPresent([Environment].self, forKey: .environments),
            quality: container.decodeIfPresent(Quality.self, forKey: .quality),
            testing: container.decodeIfPresent(Testing.self, forKey: .testing),
            git: container.decodeIfPresent(Git.self, forKey: .git)
        )
    }
}

extension ProjectConfiguration {
    /// Identity. Nothing here can be guessed from anything else.
    public struct Project: Codable, Equatable, Sendable {
        public var name: String
        public var organizationName: String
        public var bundleIdentifier: String

        public init(name: String, organizationName: String? = nil, bundleIdentifier: String) {
            self.name = name
            self.organizationName = organizationName ?? ConfigurationDefaults.organizationName
            self.bundleIdentifier = bundleIdentifier
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try self.init(
                name: container.decode(String.self, forKey: .name),
                organizationName: container.decodeIfPresent(String.self, forKey: .organizationName),
                bundleIdentifier: container.decode(String.self, forKey: .bundleIdentifier)
            )
        }
    }

    public struct Product: Codable, Equatable, Sendable {
        public var platform: ApplePlatform
        public var type: ProductType
        public var deploymentTarget: String

        public init(platform: ApplePlatform? = nil, type: ProductType? = nil, deploymentTarget: String? = nil) {
            self.platform = platform ?? ConfigurationDefaults.platform
            self.type = type ?? ConfigurationDefaults.productType
            self.deploymentTarget = deploymentTarget ?? ConfigurationDefaults.deploymentTarget
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try self.init(
                platform: container.decodeIfPresent(ApplePlatform.self, forKey: .platform),
                type: container.decodeIfPresent(ProductType.self, forKey: .type),
                deploymentTarget: container.decodeIfPresent(String.self, forKey: .deploymentTarget)
            )
        }
    }

    public struct Language: Codable, Equatable, Sendable {
        public var primary: ProgrammingLanguage
        public var languageMode: SwiftLanguageMode

        public init(primary: ProgrammingLanguage? = nil, languageMode: SwiftLanguageMode? = nil) {
            self.primary = primary ?? ConfigurationDefaults.language
            self.languageMode = languageMode ?? ConfigurationDefaults.languageMode
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try self.init(
                primary: container.decodeIfPresent(ProgrammingLanguage.self, forKey: .primary),
                languageMode: container.decodeIfPresent(SwiftLanguageMode.self, forKey: .languageMode)
            )
        }
    }

    public struct Interface: Codable, Equatable, Sendable {
        public var primary: UIFramework
        public var lifecycle: ApplicationLifecycle

        /// An omitted `lifecycle` follows from `primary`. A stated one is kept
        /// verbatim even when it contradicts `primary` — reporting that
        /// contradiction is the validation layer's job, not the decoder's.
        public init(primary: UIFramework, lifecycle: ApplicationLifecycle? = nil) {
            self.primary = primary
            self.lifecycle = lifecycle ?? primary.impliedLifecycle
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try self.init(
                primary: container.decode(UIFramework.self, forKey: .primary),
                lifecycle: container.decodeIfPresent(ApplicationLifecycle.self, forKey: .lifecycle)
            )
        }
    }

    public struct Architecture: Codable, Equatable, Sendable {
        public var pattern: ArchitecturePattern

        /// Whether to generate the pattern's example. Optional because "not
        /// stated" is a third state distinct from `true` and `false`: an
        /// unstated value follows the pattern (`generatesExample`), so choosing
        /// `mvvm` gets an example without asking while `minimal` never does. A
        /// stated `true` on a pattern with no example is rejected by validation
        /// rather than silently ignored. Nil is omitted on encode.
        public var includeExample: Bool?

        public init(pattern: ArchitecturePattern? = nil, includeExample: Bool? = nil) {
            self.pattern = pattern ?? ConfigurationDefaults.architecture
            self.includeExample = includeExample
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try self.init(
                pattern: container.decodeIfPresent(ArchitecturePattern.self, forKey: .pattern),
                includeExample: container.decodeIfPresent(Bool.self, forKey: .includeExample)
            )
        }

        /// Whether the generated project includes the pattern's example,
        /// resolving an unstated `includeExample` against the pattern: patterns
        /// with an example include it by default, `minimal` has none to include.
        public var generatesExample: Bool {
            includeExample ?? pattern.hasExample
        }
    }

    public struct Generator: Codable, Equatable, Sendable {
        public var type: GeneratorKind

        public init(type: GeneratorKind? = nil) {
            self.type = type ?? ConfigurationDefaults.generator
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try self.init(type: container.decodeIfPresent(GeneratorKind.self, forKey: .type))
        }
    }

    public struct Quality: Codable, Equatable, Sendable {
        public var swiftlint: Bool
        public var swiftformat: Bool

        public init(swiftlint: Bool? = nil, swiftformat: Bool? = nil) {
            self.swiftlint = swiftlint ?? ConfigurationDefaults.swiftlint
            self.swiftformat = swiftformat ?? ConfigurationDefaults.swiftformat
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try self.init(
                swiftlint: container.decodeIfPresent(Bool.self, forKey: .swiftlint),
                swiftformat: container.decodeIfPresent(Bool.self, forKey: .swiftformat)
            )
        }
    }

    public struct Testing: Codable, Equatable, Sendable {
        public var unit: UnitTestFramework

        public init(unit: UnitTestFramework? = nil) {
            self.unit = unit ?? ConfigurationDefaults.unitTestFramework
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try self.init(unit: container.decodeIfPresent(UnitTestFramework.self, forKey: .unit))
        }
    }

    public struct Git: Codable, Equatable, Sendable {
        public var defaultBranch: String

        public init(defaultBranch: String? = nil) {
            self.defaultBranch = defaultBranch ?? ConfigurationDefaults.defaultBranch
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            try self.init(defaultBranch: container.decodeIfPresent(String.self, forKey: .defaultBranch))
        }
    }
}

/// One build variant of the project: a build configuration, a scheme, and the
/// bundle identifier and display name it ships under.
public struct Environment: Codable, Equatable, Sendable {
    public var name: String
    public var configuration: String
    public var bundleIdentifierSuffix: String?
    public var displayNameSuffix: String?

    public init(
        name: String,
        configuration: String,
        bundleIdentifierSuffix: String? = nil,
        displayNameSuffix: String? = nil
    ) {
        self.name = name
        self.configuration = configuration
        self.bundleIdentifierSuffix = bundleIdentifierSuffix
        self.displayNameSuffix = displayNameSuffix
    }
}
