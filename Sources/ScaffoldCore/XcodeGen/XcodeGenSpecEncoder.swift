import Yams

/// Serialises an `XcodeGenSpec` into `project.yml`.
///
/// Builds a `Yams.Node` tree rather than encoding a dictionary, because a Swift
/// `Dictionary` has no order: the same spec would emit its keys differently
/// from run to run, and `project.yml` would churn in every diff.
///
/// Decides nothing. Every value it writes comes from the spec, so a question
/// about the generated file is answered by reading `XcodeGenSpecBuilder`.
struct XcodeGenSpecEncoder: Sendable {
    func encode(_ spec: XcodeGenSpec) throws -> String {
        try Yams.serialize(node: node(for: spec), sortKeys: false)
    }
}

// MARK: - Project

extension XcodeGenSpecEncoder {
    private func node(for spec: XcodeGenSpec) -> Node {
        var pairs: [(String, Node)] = [
            ("name", string(spec.name)),
            ("options", map([
                ("deploymentTarget", map([(spec.platform, string(spec.deploymentTarget))]))
            ]))
        ]

        if !spec.configurations.isEmpty {
            pairs.append(("configs", map(spec.configurations.map { configuration in
                (configuration.name, string(configuration.optimized ? "release" : "debug"))
            })))
        }

        if !spec.configFiles.isEmpty {
            pairs.append(("configFiles", map(spec.configFiles.map { ($0.configuration, string($0.path)) })))
        }

        var baseSettings: [(String, Node)] = [("SWIFT_VERSION", string(spec.languageMode))]
        if spec.strictConcurrency {
            baseSettings.append(("SWIFT_STRICT_CONCURRENCY", string("complete")))
        }
        pairs.append(("settings", map([("base", map(baseSettings))])))

        if !spec.packages.isEmpty {
            pairs.append(("packages", map(spec.packages.map { package in
                (package.name, map([
                    ("url", string(package.url)),
                    (package.requirementKey, string(package.requirementValue))
                ]))
            })))
        }

        var targets: [(String, Node)] = [(spec.name, node(forAppTargetIn: spec))]
        if let testTarget = spec.testTarget {
            targets.append((testTarget.name, node(for: testTarget, in: spec)))
        }
        if let uiTestTarget = spec.uiTestTarget {
            targets.append((uiTestTarget.name, node(for: uiTestTarget, in: spec)))
        }
        pairs.append(("targets", map(targets)))

        pairs.append(("schemes", map(spec.schemes.map { scheme in
            (scheme.name, node(for: scheme, in: spec))
        })))

        return map(pairs)
    }
}

// MARK: - Targets

extension XcodeGenSpecEncoder {
    private func node(forAppTargetIn spec: XcodeGenSpec) -> Node {
        let target = spec.appTarget

        var settings: [(String, Node)] = [
            ("base", map([
                ("PRODUCT_BUNDLE_IDENTIFIER", string(target.bundleIdentifier)),
                ("PRODUCT_DISPLAY_NAME", string(target.displayName))
            ]))
        ]

        if !target.overrides.isEmpty {
            settings.append(("configs", map(target.overrides.map { override in
                (override.configuration, map([
                    ("PRODUCT_BUNDLE_IDENTIFIER", string(override.bundleIdentifier)),
                    ("PRODUCT_DISPLAY_NAME", string(override.displayName))
                ]))
            })))
        }

        var pairs: [(String, Node)] = [
            ("type", string(target.productType)),
            ("platform", string(spec.platform)),
            ("sources", sequence(target.sources.map(string))),
            ("settings", map(settings)),
            ("info", map([
                ("path", string(target.infoPlist.path)),
                ("properties", map(properties(of: target.infoPlist)))
            ]))
        ]
        if !target.packageProducts.isEmpty {
            pairs.append(("dependencies", sequence(target.packageProducts.map(node(for:)))))
        }
        return map(pairs)
    }

    private func node(for product: XcodeGenSpec.PackageProductDependency) -> Node {
        map([
            ("package", string(product.packageName)),
            ("product", string(product.productName))
        ])
    }

    /// The display name is written as a build-setting reference so that one
    /// Info.plist serves every environment; Xcode substitutes it at build time.
    private func properties(of infoPlist: XcodeGenSpec.InfoPlist) -> [(String, Node)] {
        var properties: [(String, Node)] = [
            ("CFBundleDisplayName", string("$(PRODUCT_DISPLAY_NAME)"))
        ]

        properties += infoPlist.valueKeys.map { key in (key, string("$(\(key))")) }

        if infoPlist.includesLaunchScreen {
            properties.append(("UILaunchScreen", map([])))
        }

        if infoPlist.includesSceneManifest {
            properties.append(("UIApplicationSceneManifest", map([
                ("UIApplicationSupportsMultipleScenes", boolean(false))
            ])))
        }

        return properties
    }

    private func node(for target: XcodeGenSpec.TestTarget, in spec: XcodeGenSpec) -> Node {
        map([
            ("type", string("bundle.unit-test")),
            ("platform", string(spec.platform)),
            ("sources", sequence(target.sources.map(string))),
            // Without this the target has no Info.plist and the build fails at
            // code signing. XcodeGen does not add one for test bundles.
            ("settings", map([("base", map([("GENERATE_INFOPLIST_FILE", boolean(true))]))])),
            ("dependencies", sequence(
                [map([("target", string(spec.name))])] + target.packageProducts.map(node(for:))
            ))
        ])
    }
}

extension XcodeGenSpecEncoder {
    private func node(for target: XcodeGenSpec.UITestTarget, in spec: XcodeGenSpec) -> Node {
        map([
            ("type", string("bundle.ui-testing")),
            ("platform", string(spec.platform)),
            ("sources", sequence(target.sources.map(string))),
            ("settings", map([("base", map([("GENERATE_INFOPLIST_FILE", boolean(true))]))])),
            ("dependencies", sequence([map([("target", string(spec.name))])]))
        ])
    }
}

// MARK: - Schemes

extension XcodeGenSpecEncoder {
    private func node(for scheme: XcodeGenSpec.Scheme, in spec: XcodeGenSpec) -> Node {
        var pairs: [(String, Node)] = [
            ("build", map([("targets", map([(spec.name, string("all"))]))])),
            ("run", map([("config", string(scheme.runConfiguration))]))
        ]

        let testTargetNames = [spec.testTarget?.name, spec.uiTestTarget?.name].compactMap(\.self)
        if !testTargetNames.isEmpty {
            pairs.append(("test", map([
                ("config", string(scheme.testConfiguration)),
                ("targets", sequence(testTargetNames.map(string)))
            ])))
        }

        pairs.append(("archive", map([("config", string(scheme.archiveConfiguration))])))
        return map(pairs)
    }
}

// MARK: - Node construction

extension XcodeGenSpecEncoder {
    private func map(_ pairs: [(String, Node)]) -> Node {
        Node(pairs.map { (string($0.0), $0.1) })
    }

    /// Quoted only when the plain form would read back as something other than
    /// a string. A `.str` tag alone is not enough — the emitter still writes
    /// `18.0` bare, and YAML then hands XcodeGen the float 18, turning `18.10`
    /// into `18.1`: a different iOS release. Quoting everything would work too,
    /// but `name: 'MyApp'` throughout is noise no one wants to read.
    ///
    /// The question "would this read back as a string?" is answered by Yams'
    /// own resolver rather than by a hand-written list of shapes, which would
    /// drift from it and already over-quoted names like `3DTouch`.
    private func string(_ value: String) -> Node {
        let plain = Node(value, .implicit, .plain)
        let style: Node.Scalar.Style = Resolver.default.resolveTag(of: plain) == Tag.Name.str
            ? .any
            : .singleQuoted
        return Node(value, Tag(.str), style)
    }

    private func boolean(_ value: Bool) -> Node {
        Node(value ? "true" : "false", Tag(.bool))
    }

    private func sequence(_ items: [Node]) -> Node {
        Node(items)
    }
}
