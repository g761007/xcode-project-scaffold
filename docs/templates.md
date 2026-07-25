# Templates

A **variant** is a platform × interface pairing: the four concrete shapes a
generated project can take. It is the other axis from a [preset](presets.md),
which decides how much project comes with it.

| Variant | Platform | Interface | Lifecycle |
|---|---|---|---|
| `ios-uikit` | iOS | UIKit | `AppDelegate` + `SceneDelegate` |
| `ios-swiftui` | iOS | SwiftUI | `App` |
| `macos-swiftui` | macOS | SwiftUI | `App` |
| `macos-appkit` | macOS | AppKit | `AppDelegate`, window built in code |

In `scaffold.yml` a variant is two fields — `product.platform` and
`interface.primary` — and the lifecycle follows from them. On the command line
it is one name:

```bash
xscaffold new Ledger --variant macos-appkit --yes
```

Platform and interface pair up. `uikit` needs `ios` (`XS1001` otherwise),
`appkit` needs `macos` (`XS1002`), and `swiftui` runs on both.

## What lands on disk

Every variant produces the same shape, differing only in `App/`:

```text
.gitignore
.swiftformat
.swiftlint.yml
App/                     the sources below
Makefile                 generate, open, build, test, lint, format, clean
README.md                what this project is, written for this project
Resources/Assets.xcassets/
                         AccentColor, AppIcon, Contents.json
Tests/                   one test per generated screen
project.yml              XcodeGen's input
scaffold.yml             a record of how this project was created
```

| Variant | `App/` |
|---|---|
| `ios-uikit` | `AppDelegate.swift`, `SceneDelegate.swift`, `RootViewController.swift` |
| `ios-swiftui` | `<Name>App.swift`, `ContentView.swift` |
| `macos-swiftui` | `<Name>App.swift`, `ContentView.swift` |
| `macos-appkit` | `main.swift`, `AppDelegate.swift`, `RootViewController.swift` |

The AppKit variant ships **no storyboard and no `MainMenu.xib`**: the window and
the menu bar are built in code. That is a deliberate decision, recorded in
[ADR-0006](adr/0006-appkit-built-programmatically.md) — Interface Builder files
are machine-generated XML, which is exactly what XcodeGen exists to keep out of
a project.

## What the configuration adds

Each of these adds files without changing the ones above:

| Stated | Adds |
|---|---|
| `architecture.pattern: mvvm` / `mvvm-c` | See [architecture.md](architecture.md) |
| `testing.ui.enabled: true` | `UITests/` — a launch test and a smoke test |
| `testing.ui.launchPerformanceTest: true` | a measured launch, in the same directory |
| `environments[].values` | `Configurations/*.xcconfig`, one per configuration |
| `secrets.keys` | `Configurations/Secrets.example.xcconfig`, and the real one git-ignored |
| `localization` | `Resources/<lang>.lproj/Localizable.strings` |
| `extensions.widget` | `Widget/` — a WidgetKit extension target |
| `extensions.notificationService` | `NotificationService/` — a notification service extension |
| `ci` | `.github/workflows/build.yml`, `test.yml`, `lint.yml` |
| `dependencyManagement.mode: cocoapods` / `mixed` | `Podfile`, and a `Gemfile` with Bundler |

Both App Extensions are iOS-only in this version (`XS0012`, `XS0013`) — the
frameworks exist on macOS, the target shapes and templates do not yet.

## Two templates may not produce the same file

A run assembles its whole file list before anything reaches disk — the **File
Manifest**, where every path carries the origin that claimed it. A path claimed
twice fails with `TEMPLATE_CONFLICT`, exit code `5`, naming the path and both
claimants, and nothing is written.

This is a guardrail for template authors rather than something a user can
trigger, since the shipped template set is the only one there is.

The architecture overlay is not a conflict: replacing the variant's screen at
the same path is *declared*, and resolved before the manifest sees it.

## Placeholders

Templates are compiled into the binary and rendered with simple `{{NAME}}`
substitution in both contents and paths — which is why `App/{{PROJECT_NAME}}App.swift`
becomes `App/BookshelfApp.swift`. Structural differences arrive as *values*
rather than as conditionals in templates: a project with no linters still gets a
`lint` target in its `Makefile`, one that says so.

A surviving placeholder in generated output would often still compile, so a test
asserts that no generated file contains `{{` for any variant.

## Seeing it without generating

```bash
xscaffold plan --config scaffold.yml --files
```

Lists every file and every command the run would produce, with byte counts. It
shares `generate`'s implementation, so a preview cannot disagree with the run it
previews.
