# `scaffold.yml` reference

Everything a `scaffold.yml` can say, what it means when left out, and what this
version refuses.

`scaffold.yml` describes the **project**. It never describes a run: whether to
initialise git, whether to invoke the generator, whether to overwrite are CLI
flags, because they are not properties of the project being created.

## A complete document

```yaml
schemaVersion: 1

project:
  name: MyApp
  organizationName: My Company
  bundleIdentifier: com.example.myapp

product:
  platform: ios
  type: application
  deploymentTarget: "18.0"

language:
  primary: swift
  languageMode: "6"

interface:
  primary: uikit
  lifecycle: app-delegate-scene-delegate

architecture:
  pattern: minimal

generator:
  type: xcodegen

dependencyManagement:
  mode: none

environments: []

localization:
  developmentLanguage: en

quality:
  swiftlint: true
  swiftformat: true

testing:
  unit: swift-testing
  ui:
    enabled: false
    framework: xctest
    launchPerformanceTest: false

git:
  defaultBranch: main
```

Only three keys are required: `project.name`, `project.bundleIdentifier` and
`interface.primary`. This is a complete document:

```yaml
project:
  name: MyApp
  bundleIdentifier: com.example.myapp
interface:
  primary: swiftui
```

Everything omitted takes the default below, and the generated project's own
`scaffold.yml` records the resolved values — so what was defaulted is visible
afterwards.

## Fields

### `schemaVersion`

| | |
|---|---|
| Type | integer |
| Default | `1` |

### `project`

| Key | Type | Default | Notes |
|---|---|---|---|
| `name` | string | **required** | Becomes the Xcode target, the scheme and the directory name |
| `bundleIdentifier` | string | **required** | Reverse-DNS |
| `organizationName` | string | `""` | Appears in generated file headers |

### `product`

| Key | Type | Default | Allowed |
|---|---|---|---|
| `platform` | enum | `ios` | `ios`, `macos` |
| `type` | enum | `application` | `application`, `framework` |
| `deploymentTarget` | string | `"18.0"` on iOS, `"15.0"` on macOS | One to three dot-separated numbers |

The default follows the platform — iOS `"18.0"` has no meaning on macOS. Both are
one major release back, a defensible floor rather than the newest possible one.

**Quote `deploymentTarget`.** Unquoted, YAML reads `18.10` as the number `18.1`
— a different OS version.

### `language`

| Key | Type | Default | Allowed |
|---|---|---|---|
| `primary` | enum | `swift` | `swift` |
| `languageMode` | string | `"6"` | `"5"`, `"6"` |

`languageMode` is Xcode's `SWIFT_VERSION` build setting — a *language mode*, not
a compiler or toolchain version. Writing `"6.3.1"` there fails the build.

Objective-C is absent by design rather than pending: creating new Objective-C
projects is on no roadmap, so `objective-c` is rejected as an unrecognised value
rather than as an unsupported one.

### `interface`

| Key | Type | Default | Allowed |
|---|---|---|---|
| `primary` | enum | **required** | `uikit`, `swiftui`, `appkit` |
| `lifecycle` | enum | follows `primary` | `swiftui`, `app-delegate`, `app-delegate-scene-delegate` |

An omitted `lifecycle` is derived: `uikit` implies
`app-delegate-scene-delegate`, `swiftui` implies `swiftui`, `appkit` implies
`app-delegate`. Stating one that contradicts `primary` is an error, not an
override — leave it out unless it differs from the default, which in this
version it cannot.

There is no `interface.secondary`. Mixed-interface projects are not supported.

### `architecture`

| Key | Type | Default | Allowed |
|---|---|---|---|
| `pattern` | enum | `minimal` | `minimal`, `mvvm`, `mvvm-c`, `clean` |
| `includeExample` | boolean | per pattern | `true`, `false` |

`minimal` imposes no layering. `mvvm` and `mvvm-c` replace the app's main screen
with a worked example built in that style — a view and a concrete view model,
and for `mvvm-c` a coordinator driving a two-screen flow.

`includeExample` is a third state, not just a boolean: **left out**, it follows
the pattern — a pattern with an example includes it, `minimal` has none — so
choosing `mvvm` gets the example without stating anything. Set it to `false` to
get the pattern's structure and README notes without the example code, or omit
it. Setting it `true` on `minimal`, which has no example, is `XS1201`.

### `generator`

| Key | Type | Default | Allowed |
|---|---|---|---|
| `type` | enum | `xcodegen` | `xcodegen`, `tuist` |

### `quality`

| Key | Type | Default |
|---|---|---|
| `swiftlint` | boolean | `true` |
| `swiftformat` | boolean | `true` |

Each one switched off removes that tool's configuration file from the project
and its command from the `Makefile`'s `lint` recipe.

### `testing`

| Key | Type | Default | Allowed |
|---|---|---|---|
| `unit` | enum | `swift-testing` | `swift-testing`, `xctest`, `none` |
| `ui.enabled` | bool | `false` | |
| `ui.framework` | enum | `xctest` | `xctest` |
| `ui.launchPerformanceTest` | bool | `false` | |

`none` removes the `Tests/` directory along with the test target. A test file
that nothing compiles is worse than no test file.

`ui` is configured apart from `unit` — either can be on alone. Enabled, the
project grows a `UITests/` directory with a launch test and a smoke test (and
a measured launch when `launchPerformanceTest` asks), plus a ui-testing target
the scheme's test action runs. UI automation is XCUITest whichever unit
framework is chosen, which is why `ui.framework` has one value.

### `git`

| Key | Type | Default |
|---|---|---|
| `defaultBranch` | string | `main` |

Whether a repository is created at all is `--skip-git`, not a field here.

### `environments`

A list, empty by default, which gives the project only Xcode's own `Debug` and
`Release`. Each entry is one build variant: a build configuration, a scheme, and
the identity the app ships under.

```yaml
environments:
  - name: development
    configuration: Debug
    bundleIdentifierSuffix: .dev
    displayNameSuffix: " Dev"
  - name: staging
    configuration: Staging
    bundleIdentifierSuffix: .stg
    displayNameSuffix: " STG"
  - name: production
    configuration: Release
```

| Key | Type | Required |
|---|---|---|
| `name` | string | yes |
| `configuration` | string | yes |
| `bundleIdentifierSuffix` | string | no |
| `displayNameSuffix` | string | no |
| `values` | map of string to string | no |

The suffixes are concatenated, not substituted: `com.example.myapp` plus `.dev`
is `com.example.myapp.dev`, and `MyApp` plus `" Dev"` is `MyApp Dev`.

`values` are per-environment build values: each key lands in
`Configurations/<configuration>.xcconfig`, reaches the Info.plist as
`KEY: $(KEY)`, and is read in code through the generated `AppConfiguration`
(`API_BASE_URL` reads as `AppConfiguration.apiBaseURL`). Keys are ASCII
letters, digits and underscores, not starting with a digit.

### `secrets`

What `scaffold.yml` may say about secrets, and all it may say: a key name and
an obviously-fake example. There is no field for a real value — that absence
is the design. Both `Configurations/Secrets.example.xcconfig` and the initial
`Configurations/Secrets.xcconfig` are generated with the examples so a fresh
clone builds; only the real file is git-ignored.

```yaml
secrets:
  keys:
    - name: API_KEY
      example: sk-example-not-real
```

### `localization`

| Key | Type | Default |
|---|---|---|
| `developmentLanguage` | string | `en` |
| `languages` | list of strings | `[]` |

An empty `languages` means "not localized" and generates nothing. A localized
project lists every language it ships — the development language included —
and each gets `Resources/<language>.lproj/Localizable.strings`.

### `dependencyManagement`

| Key | Type | Default | Allowed |
|---|---|---|---|
| `mode` | enum | `none` | `none`, `spm`, `cocoapods`, `mixed` |

`none` reads nothing — declaring packages or pods under it is a validation
error, not a silent ignore. SPM is the default recommendation; `mixed` runs
both and refuses the same library arriving through each.

Packages (`spm.packages`), each stating exactly one requirement inline:

```yaml
dependencyManagement:
  mode: spm
  spm:
    packages:
      - name: Alamofire
        url: https://github.com/Alamofire/Alamofire.git
        from: "5.9.0"          # or exact: / branch: / revision:
        products:
          - name: Alamofire
            targets: [MyApp]
```

Products map to the generated targets by name — the app target and
`<name>Tests`. Pods (`cocoapods.pods`), each stating exactly one source:
`version`, `path`, or `git` with one of `tag`, `branch` or `commit`; a
`subspecs` list expands to one pod line per subspec. `cocoapods.bundler`
decodes now and takes effect in v0.6. Generation runs `pod install` after
XcodeGen and verifies the workspace it produces; Build, Test and Open then
drive the workspace.

## What this version generates

Every value listed above decodes. Only these generate; the rest are rejected by
`validate` with an `XS0xxx` code, which says "not yet" rather than
"unrecognised".

| | Supported |
|---|---|
| `product.platform` | `ios`, `macos` |
| `product.type` | `application` |
| `interface.primary` | `uikit`, `swiftui`, `appkit` |
| `architecture.pattern` | `minimal`, `mvvm`; `mvvm-c` on `uikit` only |
| `generator.type` | `xcodegen` |
| `testing.unit` | `swift-testing`, `none` |
| `product.deploymentTarget` | iOS `15.0` or later, macOS `11.0` or later |

Platform and interface pair up: `uikit` needs `ios`, `appkit` needs `macos`, and
`swiftui` runs on both. The four buildable variants are:

| | `uikit` | `swiftui` | `appkit` |
|---|---|---|---|
| **`ios`** | ✅ | ✅ | `XS1002` |
| **`macos`** | `XS1001` | ✅ | ✅ |

`mvvm` works on every one of these. `mvvm-c` is a UIKit navigation pattern, so it
is available on `ios` + `uikit` only; on `swiftui` or `appkit` it is `XS0009` —
not supported in this version, rather than never.

## Rules `validate` enforces

**`project.name`** must be usable as both an Xcode target and a directory: not
empty, no leading or trailing whitespace, not `.` or `..`, and free of `/`, `\`,
`:` and control characters.

**`project.bundleIdentifier`** must be reverse-DNS: two or more dot-separated
segments of ASCII letters, digits and hyphens, no segment starting or ending
with a hyphen. Each environment's suffixed identifier is checked too — but only
once the base is sound, so one typo produces one issue rather than one per
environment.

**`product.deploymentTarget`** must be one to three dot-separated non-negative
integers, and at or above the floor above.

**Environment names** must be unique ignoring case, because they become scheme
names and Xcode cannot hold two schemes under one name. **Build
configurations** must be unique respecting case, because Xcode really does treat
`Debug` and `debug` as two configurations.

Validation reports every problem it finds, not the first — including repeats of
one rule. It is also pure: it never looks at the machine, so the same document
validates identically everywhere. Whether *this* machine can carry the result
out is `doctor`'s question.

## Validation codes

`XS0xxx` — valid in the domain, not supported in this version. Waiting for a
release may help.

| Code | Meaning |
|---|---|
| `XS0003` | Product type not supported |
| `XS0004` | Architecture not supported |
| `XS0005` | Generator not supported |
| `XS0007` | Deployment target below the supported floor |
| `XS0008` | Test framework not supported |
| `XS0009` | MVVM-C requires UIKit; not supported for SwiftUI or AppKit |
| `XS0011` | Bundler declared but not supported until v0.6 |

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
| `XS1401` | Two environments share a name |
| `XS1402` | Two environments share a build configuration |
| `XS1403` | An environment value or secret key cannot be a build setting |
| `XS1601` | languages omits the development language |
| `XS1602` | A language is listed more than once |
| `XS1501` | A package name is declared more than once |
| `XS1502` | A package has an empty url |
| `XS1503` | A product maps to a target the project does not generate |
| `XS1504` | A pod is declared more than once |
| `XS1505` | The same library is declared as both a package and a pod |
| `XS1506` | Packages or pods are declared under a mode that never reads them |

A document that cannot be parsed at all — bad YAML, a missing required key, an
unrecognised enum value — never reaches validation. That exits `3` with a
`message` and no `issues`, because there is no configuration to find issues in.
