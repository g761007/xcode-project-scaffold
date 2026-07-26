# `scaffold.yml`

Every field, its default, and what it is allowed to be.

Three fields are required — `project.name`, `project.bundleIdentifier` and
`interface.primary`. Everything else has a default, and a
[preset](presets.md) supplies what you leave out.

```yaml
project:
  name: Bookshelf
  bundleIdentifier: com.example.bookshelf
interface:
  primary: swiftui
```

To see what an omitted field will actually be:

```bash
xscaffold config example --preset standard     # a resolved document to edit
xscaffold plan --config scaffold.yml --resolved-config
```

> The Skill ships the same reference at
> [`Skills/xcode-project-scaffold/references/configuration-schema.md`](../Skills/xcode-project-scaffold/references/configuration-schema.md),
> written for an agent rather than a person. A test asserts that both documents
> cover every validation code and every allowed value, so neither can fall
> behind the schema.

## `schemaVersion`

| Type | Default |
|---|---|
| integer | `1` |

The document's format version. Generated files state it; hand-written ones can
leave it out.

## `preset`

| Type | Default | Allowed |
|---|---|---|
| enum | none | `minimal`, `standard`, `production` |

How much project. Fully described in [presets.md](presets.md).

## `project`

| Key | Type | Default | Notes |
|---|---|---|---|
| `name` | string | **required** | Becomes the Xcode target, the scheme and the directory name |
| `bundleIdentifier` | string | **required** | Reverse-DNS |
| `organizationName` | string | `""` | Appears in generated file headers |

## `product`

| Key | Type | Default | Allowed |
|---|---|---|---|
| `platform` | enum | `ios` | `ios`, `macos` |
| `type` | enum | `application` | `application`, `framework` |
| `deploymentTarget` | string | `"18.0"` on iOS, `"15.0"` on macOS | One to three dot-separated numbers |

The default follows the platform — iOS `"18.0"` means nothing on macOS. Both are
one major release back: a defensible floor rather than the newest possible one.

**Quote `deploymentTarget`.** Unquoted, YAML reads `18.10` as the number `18.1`,
which is a different OS version.

Only `application` generates in this version; `framework` decodes and is
refused as `XS0003`.

## `language`

| Key | Type | Default | Allowed |
|---|---|---|---|
| `primary` | enum | `swift` | `swift` |
| `languageMode` | string | `"6"` | `"5"`, `"6"` |

`languageMode` is Xcode's `SWIFT_VERSION` build setting — a *language mode*, not
a compiler or toolchain version. Writing `"6.3.1"` there fails the build.

Objective-C is absent by design rather than pending: creating new Objective-C
projects is on no roadmap, so `objective-c` is rejected as an unrecognised value
rather than as an unsupported one.

## `interface`

| Key | Type | Default | Allowed |
|---|---|---|---|
| `primary` | enum | **required** | `uikit`, `swiftui`, `appkit` |
| `lifecycle` | enum | follows `primary` | `swiftui`, `app-delegate`, `app-delegate-scene-delegate` |

An omitted `lifecycle` is derived: `uikit` implies
`app-delegate-scene-delegate`, `swiftui` implies `swiftui`, `appkit` implies
`app-delegate`. Stating one that contradicts `primary` is an error rather than
an override — leave it out unless it differs from the default, which in this
version it cannot.

There is no `interface.secondary`; mixed-interface projects are not supported.

Platform and interface pair up: `uikit` needs `ios` (`XS1001`), `appkit` needs
`macos` (`XS1002`), `swiftui` runs on both. See [templates.md](templates.md).

## `architecture`

| Key | Type | Default | Allowed |
|---|---|---|---|
| `pattern` | enum | `minimal` | `minimal`, `mvvm`, `mvvm-c`, `clean` |
| `includeExample` | boolean | per pattern | `true`, `false` |

`clean` decodes and is refused as `XS0004`; `mvvm-c` is UIKit-only in this
version (`XS0009`). Fully described in [architecture.md](architecture.md).

`includeExample` has three states, not two. **Left out**, it follows the
pattern — so `mvvm` brings its example without stating anything, and `minimal`
brings none. `true` on `minimal` is `XS1201`, permanently.

The SwiftUI example observes with `@Observable`, which needs iOS 17 / macOS 14.
Below that floor it is `XS0014`, refused before anything is written rather than
generating a project that cannot compile.

## `generator`

| Key | Type | Default | Allowed |
|---|---|---|---|
| `type` | enum | `xcodegen` | `xcodegen`, `tuist` |

`tuist` decodes and is refused as `XS0005`.

## `quality`

| Key | Type | Default |
|---|---|---|
| `swiftlint` | boolean | `true` |
| `swiftformat` | boolean | `true` |

Each one switched off removes that tool's configuration file from the project
and its command from the `Makefile`'s `lint` recipe. Neither configuration lists
the directories to look at, so both cover every source directory the project
actually has.

## `testing`

| Key | Type | Default | Allowed |
|---|---|---|---|
| `unit` | enum | `swift-testing` | `swift-testing`, `xctest`, `none` |
| `ui.enabled` | boolean | `false` | |
| `ui.framework` | enum | `xctest` | `xctest` |
| `ui.launchPerformanceTest` | boolean | `false` | |

`none` removes the `Tests/` directory along with the test target: a test file
that nothing compiles is worse than no test file. `xctest` decodes and is
refused as `XS0008`.

`ui` is configured apart from `unit`, and either can be on alone. Enabled, the
project grows `UITests/` with a launch test and a smoke test — plus a measured
launch when `launchPerformanceTest` asks — and a ui-testing target the scheme's
test action runs. UI automation is XCUITest whichever unit framework is chosen,
which is why `ui.framework` has one value.

## `environments`

A list, empty by default, which leaves the project with Xcode's own `Debug` and
`Release`. Each entry is one build variant: a configuration, a scheme, and the
identity the app ships under.

```yaml
environments:
  - name: development
    configuration: Debug
    bundleIdentifierSuffix: .dev
    displayNameSuffix: " Dev"
    values:
      API_BASE_URL: https://dev.example.com
  - name: production
    configuration: Release
    values:
      API_BASE_URL: https://api.example.com
```

| Key | Type | Required |
|---|---|---|
| `name` | string | yes |
| `configuration` | string | yes |
| `bundleIdentifierSuffix` | string | no |
| `displayNameSuffix` | string | no |
| `values` | map of string to string | no |

The suffixes are concatenated, not substituted: `com.example.bookshelf` plus
`.dev` is `com.example.bookshelf.dev`, and `Bookshelf` plus `" Dev"` is
`Bookshelf Dev`.

`values` become per-environment build values: each key lands in
`Configurations/<configuration>.xcconfig`, reaches the Info.plist as
`KEY: $(KEY)`, and is read in code through the generated `AppConfiguration` —
`API_BASE_URL` reads as `AppConfiguration.apiBaseURL`. Keys are ASCII letters,
digits and underscores, not starting with a digit (`XS1403`).

Names must be unique ignoring case (`XS1401`), because they become scheme names
and Xcode cannot hold two schemes under one name. Configurations must be unique
respecting case (`XS1402`), because Xcode really does treat `Debug` and `debug`
as two configurations.

## `secrets`

What `scaffold.yml` may say about secrets, and all it may say: a key name and an
obviously-fake example. **There is no field for a real value** — that absence is
the design.

```yaml
secrets:
  keys:
    - name: API_KEY
      example: sk-example-not-real
```

Both `Configurations/Secrets.example.xcconfig` and the initial
`Configurations/Secrets.xcconfig` are generated with the examples, so a fresh
clone builds. Only the real file is git-ignored.

## `localization`

| Key | Type | Default |
|---|---|---|
| `developmentLanguage` | string | `en` |
| `languages` | list of strings | `[]` |

An empty `languages` means "not localized" and generates nothing. A localized
project lists every language it ships — the development language included
(`XS1601`), each exactly once (`XS1602`) — and each gets
`Resources/<language>.lproj/Localizable.strings`.

## `dependencyManagement`

| Key | Type | Default | Allowed |
|---|---|---|---|
| `mode` | enum | `none` | `none`, `spm`, `cocoapods`, `mixed` |

`none` reads nothing, and declaring packages or pods under it is a validation
error rather than a silent ignore (`XS1506`).

Fully described in [dependencies.md](dependencies.md) and
[cocoapods.md](cocoapods.md).

### `spm.packages`

Each package states exactly one requirement — `from`, `exact`, `branch` or
`revision` — inline:

```yaml
dependencyManagement:
  mode: spm
  spm:
    packages:
      - name: Alamofire
        url: https://github.com/Alamofire/Alamofire.git
        from: "5.9.0"
        products:
          - name: Alamofire
            targets: [Bookshelf]
```

`products[].targets` names generated targets: the app target, `<name>Tests`,
`<name>UITests`, and any App Extension. A target that is not generated is
`XS1503`. A package name declared twice is `XS1501`; an empty `url` is `XS1502`.

### `cocoapods`

| Key | Type | Notes |
|---|---|---|
| `pods` | list | Each states exactly one source: `version`, `path`, or `git` with one of `tag`, `branch`, `commit`. A `subspecs` list expands to one pod line per subspec. |
| `sources` | list of strings | Spec repositories, in declaration order. |
| `bundler.enabled` | boolean | Generates a `Gemfile` and installs through `bundle exec`. |
| `bundler.cocoapodsVersion` | string | The version the Gemfile pins. Omitted, it takes whatever resolves. |

A pod declared twice is `XS1504`; a library arriving as both a package and a pod
is `XS1505`; a duplicate source is `XS1507` and an empty one `XS1508`.

A source URL may carry credentials (`https://user:token@host`). Logs, error
messages and JSON output always show it masked as `https://***@host`, while
`scaffold.yml` and the Podfile keep the original text — they are your own files.
That is not a reason to commit one.

## `extensions`

| Key | Type | Default |
|---|---|---|
| `widget.enabled` | boolean | `true` when `widget` is stated |
| `notificationService.enabled` | boolean | `true` when `notificationService` is stated |

Omitted entirely — and stated while naming no extension — generates nothing.
Naming an extension is what asks for it; `enabled: false` parks the section
without generating the target. The two are independent.

```yaml
extensions:
  widget: {}
  notificationService: {}
```

| | Directory | Identifier suffix | Boundary |
|---|---|---|---|
| `widget` | `Widget/` | `.widget` | `XS0012` — iOS only |
| `notificationService` | `NotificationService/` | `.notificationservice` | `XS0013` — iOS only |

Each becomes an `app-extension` target the app embeds, shipping under the app's
bundle identifier plus a suffix — per environment as well as at the base,
because an extension whose identifier is not prefixed by its container's cannot
be installed.

`widget` generates a `WidgetBundle` entry point and a static-configuration
widget. `notificationService` generates a `UNNotificationServiceExtension`
subclass named `NotificationService`; that name is load-bearing, because the
target's `NSExtensionPrincipalClass` points at it and the system instantiates it
by name.

## `ci`

| Key | Type | Default | Allowed |
|---|---|---|---|
| `provider` | enum | `github-actions` | `github-actions` |
| `workflows.build` | boolean | `true` | |
| `workflows.test` | boolean | `true` | |
| `workflows.lint` | boolean | `true` | |

Omitted entirely, no CI files are generated — CI is a choice, not a default.
Stated, each enabled switch adds one workflow under `.github/workflows/`.

Build and test regenerate the project with XcodeGen, install what the dependency
mode reads, and drive `xcodebuild` against the project or the workspace — the
same container rule every other command follows. Lint installs the enabled
linters and runs `make lint`, the generated Makefile's own recipe, so the
workflow cannot drift from what a developer runs.

## `git`

| Key | Type | Default |
|---|---|---|
| `defaultBranch` | string | `main` |

Whether a repository is created at all is `--skip-git`, not a field here:
execution behaviour lives in flags, never in the document.

## Rules `validate` enforces

**`project.name`** must be usable as both an Xcode target and a directory: not
empty, no leading or trailing whitespace, not `.` or `..`, and free of `/`,
`\`, `:` and control characters (`XS1304`).

**`project.bundleIdentifier`** must be reverse-DNS: two or more dot-separated
segments of ASCII letters, digits and hyphens, no segment starting or ending
with a hyphen (`XS1301`). Each environment's suffixed identifier is checked
too — but only once the base is sound, so one typo produces one issue rather
than one per environment.

**`product.deploymentTarget`** must be one to three dot-separated non-negative
integers (`XS1302`), at or above the floor for its platform (`XS0007`).

Validation reports **every** problem it finds, not the first. It is also pure:
it never looks at the machine, so the same document validates identically
everywhere. Whether *this* machine can carry the result out is `doctor`'s
question.

## Validation codes

`XS0xxx` — valid in the domain, not supported in this version. A later release
may lift it.

| Code | Meaning |
|---|---|
| `XS0003` | Product type not supported |
| `XS0004` | Architecture not supported |
| `XS0005` | Generator not supported |
| `XS0007` | Deployment target below the supported floor |
| `XS0008` | Test framework not supported |
| `XS0009` | MVVM-C requires UIKit; not supported for SwiftUI or AppKit |
| `XS0012` | Widget extensions are only generated for iOS |
| `XS0013` | Notification Service extensions are only generated for iOS |
| `XS0014` | The SwiftUI architecture example needs iOS 17 / macOS 14 |

`XS1xxx` — invalid in every version. Waiting will not help.

| Code | Meaning |
|---|---|
| `XS1001` | UIKit requires iOS |
| `XS1002` | AppKit requires macOS |
| `XS1101` | The `swiftui` lifecycle requires SwiftUI |
| `XS1102` | The `app-delegate-scene-delegate` lifecycle requires UIKit |
| `XS1103` | The `app-delegate` lifecycle requires AppKit |
| `XS1201` | `includeExample` requires an architecture that has an example |
| `XS1301` | Bundle identifier is not reverse-DNS |
| `XS1302` | Deployment target is not a version number |
| `XS1304` | Project or environment name cannot be used as a target or scheme name |
| `XS1305` | A value contains a control character |
| `XS1401` | Two environments share a name |
| `XS1402` | Two environments share a build configuration |
| `XS1403` | An environment value or secret key cannot be a build setting |
| `XS1501` | A package name is declared more than once |
| `XS1502` | A package has an empty url |
| `XS1503` | A product maps to a target the project does not generate |
| `XS1504` | A pod is declared more than once |
| `XS1505` | The same library is declared as both a package and a pod |
| `XS1506` | Packages or pods are declared under a mode that never reads them |
| `XS1507` | A pod source is declared more than once |
| `XS1508` | A pod source is empty |
| `XS1601` | `languages` omits the development language |
| `XS1602` | A language is listed more than once |

A document that cannot be parsed at all — bad YAML, a missing required key, an
unrecognised enum value — never reaches validation. That exits `3` with an
`error` and no `issues`, because there is no configuration to find issues in.

## Editor support

Generated documents open with a schema annotation, and it is worth putting at
the top of a hand-written one:

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/g761007/xcode-project-scaffold/main/Schemas/scaffold.schema.json
```

An editor with the YAML language server then completes field names and flags
unknown ones as you type.
