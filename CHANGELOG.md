# Changelog

All notable changes to `xscaffold` are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

`xscaffold` uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html), but
the `0.x` series makes **no compatibility promise**: the `scaffold.yml` schema,
the CLI contract, the JSON output and the exit codes may change without a
migration path until `1.0` (see the README).

## [Unreleased]

### Added
- **Shell completions for zsh, bash and fish.** Homebrew installs all three;
  `xscaffold --generate-completion-script <shell>` writes one for any other
  installation. Beyond subcommands and flags, the values worth not having to
  remember complete too: `--variant` offers the four variants, `--preset` the
  three presets, `--config` and `validate` offer `.yml` and `.yaml` files, and
  `--destination` offers directories. The value lists are read out of the
  binary's own types rather than written into a script, so a fifth variant
  completes the day it exists — and a test asserts that, against
  `Variant.all` and `Preset.allowedValues`, in all three scripts.

- **Every failure names itself.** `--output json` failures now carry an `error`
  object — `code`, `message`, `exitCode`, `recoverySuggestion`, plus `command`
  when an external command failed and `path` when the failure is about a file —
  and a `phase` saying which stage the run reached. A caller can tell
  `POD_INSTALL_FAILED` from `XCODEGEN_FAILED` without parsing English, and tell
  a failure that wrote nothing from one that left a directory behind. In text
  mode the same facts arrive as `Error: CODE: message` followed by `Try: …`.

  The codes are the error contract's (§23), minus the six it names that no
  failure path could emit — an unreachable code is dead the same way an
  unreachable validation code is — plus the ones that existed with no name:
  wrong arguments, an unreadable configuration, a malformed one, and the two
  catch-alls. `phase` follows ADR-0009: the stage that was under way, not the
  state the run ended in.

  Every code carries its own exit code and its own recovery suggestion, so a
  new failure mode cannot ship without deciding both.



- **`config example` takes `--variant` and `--dependency-manager`**, the two
  flags §4.9 documents beside `--preset`. All three are independent axes, as
  they are on `new`: the variant states the platform and the interface (and
  what follows from them — an AppKit example says `lifecycle: app-delegate`),
  the preset states how much project, and the dependency manager states what
  reads the packages. An unknown name for any of them is refused with the real
  ones, and a variant given to `--preset` is now pointed at `--variant` rather
  than at the document.

  The dependency manager earns a flag rather than being a word to edit because
  it is not one word in the resolved document: under `production`, choosing
  pods also pins Bundler and a CocoaPods version during normalization. An
  example that hid that would be hiding what its reader is about to generate,
  which is the one thing this command exists not to do.

  All three route through the same document builder `new --variant --preset`
  uses, so the same two flags cannot come to mean different things depending on
  which command they follow.

### Fixed
- **A generated project's `make lint` now looks at everything it generated.**
  Its `.swiftlint.yml` listed `App` and `Tests` under `included:`, so `UITests/`
  (since v0.5), `Widget/` and `NotificationService/` (both since v0.6) were
  never read — and `make lint` reported zero violations without having opened
  them. The list is gone rather than extended: SwiftLint reads the working
  directory by default, which is exactly the set of directories the project
  actually has, and cannot fall behind the next one.

  Both linters now leave `Pods/` alone. Dropping the include list would
  otherwise have pointed SwiftLint at vendored sources, and SwiftFormat has
  been rewriting them all along — `make format` in a CocoaPods project
  reformatted third-party code.

- **The UI test templates did not pass the linters they ship with.** Three
  `func test…() throws` with nothing throwing in them, which `swiftformat
  --lint` refuses, so `make lint` failed in every generated project with UI
  tests switched on. Present since v0.5; caught now because the CI job that
  lints generated projects finally generates one with UI tests and both App
  Extensions in it.

## [0.7.0] — 2026-07-25

### Added

- **Presets.** `minimal`, `standard` and `production` — a project's scale, and
  the set of defaults that follows from it. `minimal` is the bare skeleton;
  `standard` is MVVM with its example, SPM, Swift Testing, both linters and two
  environments; `production` adds UI tests, a third environment with xcconfig
  values, a secrets example, localization and GitHub Actions workflows. Naming
  one changes only fields the document leaves unstated — anything written wins,
  including an explicit `false` against a preset's `true` — so a preset is a
  starting point rather than a mode the rest of the file works around. The
  resolution order is fixed: preset defaults → your overrides → normalization →
  validation. `production` with `dependencyManagement.mode: cocoapods` also
  pins Bundler and the CocoaPods version in normalization, because that is what
  the teams who reach for CocoaPods came for.

  Presets merge as YAML nodes rather than as values (ADR-0008): only the
  document still knows which fields were stated, and that distinction is the
  whole mechanism. `capabilities` grows a `presets` field.
- **`--preset` returns, as a scale rather than a platform combination.** It is
  orthogonal to `--variant`: one picks the platform and interface, the other
  picks how much project comes with them, and
  `new App --variant ios-swiftui --preset standard --yes` is a one-line
  generation. The flag routes through the document, so it and a `scaffold.yml`
  saying `preset: standard` resolve through one mechanism instead of two that
  can disagree. A variant name given to `--preset` still gets a pointer to
  `--variant`, since the four platform combinations hung off this flag until
  v0.4.
- **`config example`.** `xscaffold config example --preset standard > scaffold.yml`
  prints an editable configuration to start from — the preset resolved in full,
  not a single `preset:` line, because an example exists to be read and
  changed. It prints rather than writes, so the shell decides where the file
  goes and nothing it does can overwrite anything. The identity is a
  placeholder that validates as it stands, and the document carries the same
  schema annotation `generate` records, from the same source.
- **The File Manifest.** A run assembles its whole file list before anything
  reaches disk, with each path carrying the origin that claimed it — a template
  layer's directory, or the renderer that produced it. A path claimed twice
  fails with `TEMPLATE_CONFLICT`, exit code 5, naming the path and both
  claimants, rather than being won by whichever was added last. The
  architecture overlay's same-path replacement is declared and resolved before
  the manifest, so it is not a conflict.

### Fixed

- **Generated iOS UIKit apps launched with no window.** The scene manifest
  declared `UIApplicationSupportsMultipleScenes` and nothing else, so the
  configuration the generated `AppDelegate` asks UIKit for by name did not
  exist, `SceneDelegate` was never instantiated, and the window it builds never
  appeared. The app still built, still passed its tests, and still reported
  itself running in the foreground — which is why nothing caught it.

  Present since v0.1, in every iOS UIKit project regardless of architecture.
  SwiftUI and macOS AppKit never had a scene manifest and were unaffected.

  Nothing caught it because nothing looked: unit tests instantiate the view
  controller directly, and while the UI test templates added in v0.5 do assert
  that a window exists, no e2e case had ever switched UI tests on. The
  `production` preset does, and its e2e case was the first run to launch a
  generated UIKit app and look at it.

### Changed

- The e2e matrix gains four preset cases: `standard` and `production` each at
  the **floor its own contents impose** rather than the default target,
  `production` again with CocoaPods, and one through `--preset` itself. That
  floor is not one number — both presets bring the MVVM example, and the
  SwiftUI example cannot go below iOS 17 while the UIKit one builds at 15.0 —
  so the two cases take one floor each.
- README documents presets: what each scale brings, that a preset and a variant
  are independent axes, and how a preset interacts with what a document states.

## [0.6.1] — 2026-07-25

### Fixed

- **The SwiftUI architecture example no longer generates a project that cannot
  compile.** It observes its view model with `@Observable`, which arrived in
  iOS 17 and macOS 14, while the project floor is iOS 15 and macOS 11. Between
  the two, `architecture.includeExample` on SwiftUI validated, generated, and
  then failed to build on six errors from a macro the template chose. It is now
  `XS0014`, reported before anything is written, and it faults
  `includeExample` — switching the example off keeps the pattern's structure
  and README notes, which is the fix that leaves the project as asked. Raising
  `product.deploymentTarget` is the other suggestion; both were built to
  confirm they work.

  The rule is deliberately narrow, and its scope was established by building
  every variant and architecture at the floor rather than by reasoning about
  them: `minimal` has no example, and the UIKit and AppKit examples observe
  through a closure and build at the floor, so none of them is refused.

  Present since v0.5. Projects on the default deployment target were never
  affected.

### Changed

- Two e2e cases carry the boundary: the SwiftUI example at exactly `17.0`,
  which is where the validator claims the boundary sits and where the
  default-target case says nothing, and the pattern without its example at
  `15.0`, so the suggestion is not a dead end.

## [0.6.0] — 2026-07-25

### Added

- **Bundler and CocoaPods version pinning.** `dependencyManagement.cocoapods.bundler`
  writes a `Gemfile` beside the Podfile and changes the install sequence to
  `bundle install` → `bundle exec pod install`, so every machine and every CI
  run installs pods with the CocoaPods the Gemfile names rather than whichever
  one is on the `PATH`. `cocoapodsVersion` pins it; omitted, the Gemfile takes
  whatever resolves. `doctor` follows: with Bundler it requires `bundle` and
  stops requiring `pod`, because `bundle exec` provides that one itself.
  `BUNDLER_NOT_INSTALLED` joins the error contract.
- **Ordered pod sources, with credentials masked.** `cocoapods.sources` keeps
  declaration order, so a private specs repo listed before the public CDN
  resolves internal pods first. A credential embedded in a source URL is masked
  everywhere xscaffold prints it — log output, `--output json`, and validation
  messages alike — and is not masked in the Podfile, which needs the real URL
  to work.
- **GitHub Actions workflows.** The `ci` section generates `build.yml`,
  `test.yml` and `lint.yml` under `.github/workflows/`. Omitting it generates
  nothing — CI is a choice, not a default — while stating it turns every switch
  on. Each workflow rebuilds the project the way a person would: XcodeGen, then
  whatever the dependency mode reads, then `xcodebuild` against the project or
  the workspace, following the same container rule every other command does.
  Lint runs `make lint`, the generated Makefile's own recipe, so the workflow
  and a laptop cannot come to different conclusions.
- **App Extensions.** The `extensions` section generates `widget` (a
  `WidgetBundle` and a static-configuration widget) and `notificationService`
  (a `UNNotificationServiceExtension` subclass). Naming an extension is what
  asks for it; omitting the section, or stating it while naming nothing,
  generates nothing. Each becomes an `app-extension` target the app embeds,
  with its own sources directory, and ships under the app's bundle identifier
  plus a suffix — per environment as well as at the base, because an extension
  whose identifier is not prefixed by its container's cannot be installed. A
  package product may name an extension target exactly as it may name the
  app's. Both are iOS-only in this version (`XS0012`, `XS0013`).
- **A fourth template layer.** `Features/<feature>` holds the sources of one
  optional part of a generated project. A feature contributes its own files and
  patches no other template, so it lands beside the Shared, Variant and
  Architecture layers rather than overlaying them.

### Changed

- The e2e matrix gains the Bundler combination — `bundle install` →
  `bundle exec pod install` → workspace build and test, asserting that the
  Gemfile carries the pin and that `bundle install` left its lock beside it —
  and an extensions combination carrying both extensions at the **supported
  deployment floor** rather than the default, which is the value that actually
  exercises availability.
- README documents the enterprise path: Bundler, pod sources, `ci`, and the two
  App Extensions.

### Removed

- **`init`.** Its deprecation period ended as scheduled. Typing it gets a clear
  pointer to `generate` or `new --variant --yes` rather than an unknown-command
  error, and the contract tests assert that error and its exit code. The
  reasoning is recorded in ADR-0007.

## [0.5.0] — 2026-07-25

### Added

- **Dependencies.** `dependencyManagement.mode` — `none`, `spm`, `cocoapods`
  or `mixed`. Packages state one of SwiftPM's four requirements inline and
  map products to targets; they land in `project.yml` and resolve on first
  build. Pods state exactly one source (`version`, `path`, or `git` with one
  of `tag`/`branch`/`commit`) with subspec expansion; xscaffold writes the
  Podfile, runs `pod install` after XcodeGen, and verifies the workspace it
  produced. Mixed mode runs both and refuses the same library arriving
  through each. The validator holds the structural rules (XS15xx) and
  `doctor` requires CocoaPods exactly when the configuration reads pods.
- **ProjectContainer.** Build, Test and Open decide `-project` versus
  `-workspace` in exactly one place: CocoaPods and mixed drive the workspace,
  everything else the project file.
- **UI tests.** `testing.ui` — apart from `testing.unit` — grows a ui-testing
  target with a launch test, a smoke test, and an optional measured launch.
- **Environment values and secrets.** `environments[].values` become
  per-configuration `.xcconfig` files, reach the Info.plist as `$(KEY)`
  references, and are read through the generated `AppConfiguration`.
  `secrets.keys` may state a name and an obviously-fake example — there is no
  field for a real value, and that absence is the design; only the real
  `Secrets.xcconfig` is git-ignored.
- **Localization.** `localization.languages` generates one lproj per shipped
  language; `project.yml` states the development language only when it says
  something.
- **`capabilities`.** What this binary actually generates, machine-readable,
  sourced from the same sets the validator enforces — what is rejected is not
  advertised.
- **JSON Schema.** `Schemas/scaffold.schema.json` ships with the repository;
  every generated `scaffold.yml` opens with a `yaml-language-server`
  annotation pointing at it, so editors validate while you type.
- **The e2e dependency matrix.** Representative combinations — SPM, CocoaPods
  and mixed on iOS, CocoaPods on macOS — generated by the real binary,
  installed by the real tools, and tested through the workspace where one
  exists.

### Changed

- The e2e suite and the Skill drive the modern surface — `capabilities`,
  `validate`, `plan`, `generate --yes`, `new --variant --yes` — ahead of
  `init`'s removal in v0.6.

## [0.4.0] — 2026-07-25

### Added

- **`generate` — the non-interactive generation entrance.** Reads an existing
  `scaffold.yml` (`--config`, defaulting to `./scaffold.yml`), shows a summary
  — including anything a forced run would overwrite — and asks before writing.
  `--yes` skips the question but never the validation, the plan or the
  destination rules; without a terminal and without `--yes` it refuses with
  exit 2 rather than hanging a pipeline on a prompt no one can see.
- **Preview-first `new`.** The questions end at a Configuration Preview and a
  menu — Generate project, Save scaffold.yml and exit, Edit configuration,
  Show complete file plan, Show resolved configuration, Cancel — and nothing
  touches disk until an option says otherwise. Save writes the same bytes
  generating would have written; Edit re-asks one section and comes back to a
  fresh preview, as many rounds as it takes; Cancel exits 130 with nothing on
  disk, from any depth.
- **`--variant`.** The four platform × interface combinations move from
  `--preset` to their CONTEXT.md name: `new MyApp --variant ios-uikit --yes`
  is the one-line generation, needing no terminal. Typing `--preset` on `new`
  gets "did you mean --variant?" instead of an unknown-option error.
- **`new --advanced` and `new --open`.** Advanced appends questions for the
  fields most projects leave at their defaults — organization name, deployment
  target, unit test framework, the SwiftLint/SwiftFormat switches, the git
  default branch. `--open` opens the generated project on success.
- **`plan --files` and `plan --resolved-config`.** The preview's two Show
  options as flags: the full file-and-command listing, and the configuration
  with every default resolved — in text and JSON (`resolvedConfiguration`
  joins the document only when asked for).
- **Two-tier destination rules.** A directory already holding a project — an
  `.xcodeproj`, `.xcworkspace`, `project.yml` or top-level Swift source — is
  refused outright (`OUTPUT_DIRECTORY_HAS_PROJECT`), and no flag can downgrade
  that. A merely non-empty directory (`OUTPUT_DIRECTORY_NOT_EMPTY`) admits
  `--force`, which is what makes scaffolding inside a GitHub-starter clone
  work; what a forced run would overwrite is listed in the plan, the preview
  and the JSON (`overwrites`) before it happens. A directory holding only a
  `scaffold.yml` needs no flag at all.
- **Tag-triggered releases.** Pushing a `v*` tag runs the full test gate,
  builds an arm64 + x86_64 universal binary, packages it with a SHA256,
  creates the GitHub Release with the CHANGELOG section as its notes, and
  smoke-tests the published artifact — `--version` must equal the tag, and a
  one-line `new --variant --yes --validate-build` must produce a building
  project. The version has one source: the tag, stamped at build time. Source
  builds report `0.0.0-dev`.
- **Community files.** CONTRIBUTING, SECURITY, a code of conduct, issue and PR
  templates, and a terminal demo recorded from the real binary
  (`Scripts/record-demo.sh`).

### Deprecated

- **`init`.** Still works, warns on every run — `generate --config` for
  configurations, `new --variant --yes` for the one-line run — and is removed
  in v0.6. The reasoning, including the preset→variant vocabulary move, is
  ADR-0007.

### Changed

- The README now leads with the preview-first flow and the one-line Homebrew
  install; every example matches the shipped CLI.
- The `Preset` type is `Variant` in code, matching CONTEXT.md; a deprecated
  alias keeps `init` compiling until it goes.

## [0.3.0] — 2026-07-24

### Added

- **macOS support.** `product.platform: macos` now generates a project, through
  two new variants — `macos-swiftui` and `macos-appkit` — each built and tested
  on macOS in CI. The lifecycle follows the interface: macOS SwiftUI uses the App
  lifecycle, macOS AppKit an `NSApplicationDelegate`, since macOS has no scenes.
- **The AppKit variant is built entirely in code.** `macos-appkit` ships no
  `Main.storyboard` and no `MainMenu.xib`: a `main.swift` entry point, an
  `NSApplicationDelegate` that assembles the window and an `NSMenu` menu bar, and
  a code-built `NSViewController`. Interface Builder files are the
  machine-generated XML XcodeGen exists to keep out of the project ([ADR-0006](docs/adr/0006-appkit-built-programmatically.md)).
- **MVVM on macOS.** The MVVM example now generates for both macOS variants,
  reusing the framework-free view model.
- **`macos-swiftui` and `macos-appkit` presets**, joining the two iOS presets.
- **A platform question in `xscaffold new`.** It is asked first; every interface
  is offered on every platform, and a pairing the platform forbids is left to
  `validate`, which re-asks the offending question — the prompt holds no
  compatibility rule of its own.
- **A platform-aware deployment target default:** iOS `18.0`, macOS `15.0`.

### Changed

- The `Shared` template layer no longer carries the `AppIcon`; it moved down to
  each variant, because the iOS and macOS icons differ. Generated iOS projects
  are unchanged.

### Validation

- `XS0001` (platform not supported) and `XS0006` (interface not supported) are
  removed. With every platform and interface now accepted, no configuration could
  trigger them, and a dead code is worse than none.
- `XS0009` now reads "MVVM-C is only available on UIKit in this version" and
  covers AppKit as well as SwiftUI.
- `XS1001` (UIKit requires iOS), `XS1002` (AppKit requires macOS) and `XS1103`
  (the `app-delegate` lifecycle requires AppKit) now have reachable
  configurations for the first time.

## [0.2.0] — 2026-07-24

### Added

- **MVVM and MVVM-C architectures.** `architecture.pattern` now accepts `mvvm`
  and `mvvm-c`. Each generates a worked example that replaces the app's main
  screen — a view and a concrete view model, and for MVVM-C an `AppCoordinator`
  driving a two-screen list→detail flow. MVVM works on UIKit and SwiftUI;
  MVVM-C is UIKit-only.
- **`architecture.includeExample`.** Controls whether the example is generated.
  Left out, it follows the pattern — a pattern with an example includes it,
  `minimal` has none — so choosing `mvvm` gets the example without stating
  anything. Nil is omitted on encode, so existing `scaffold.yml` output is
  unchanged.
- **Interactive `xscaffold new` command.** Asks a few questions — name, bundle
  identifier, interface, architecture, whether to include the example, and the
  environments — then runs the same pipeline `init` does. It holds no
  compatibility rules of its own: it collects answers, lets `validate` decide,
  and re-asks the question a failure points at. It needs a terminal; `--yes`
  skips the final confirmation.
- **Exit code `130`** for a cancelled `new` — a "no" at the confirmation, ended
  input, or Ctrl-C — which leaves nothing on disk.
- A Mermaid diagram of the chosen pattern in the generated project's README.

### Changed

- The architecture overlay now contributes source (the example) in addition to
  the README's architecture note, replacing the variant's default screen at the
  same path.
- `init` is unchanged and stays non-interactive and scriptable; its final
  steps — write, verify-build, report — are now shared with `new`.

### Validation

- `XS0009`: MVVM-C is not supported for SwiftUI in this version (a boundary, not
  an impossibility).
- `XS1201`: `includeExample: true` is invalid for `minimal`, which has no
  example.
- `XS0004` no longer rejects `mvvm` or `mvvm-c` on UIKit.

## [0.1.0] — 2026-07-23

Initial release.

- The `init`, `validate`, `plan` and `doctor` commands, each with `--output
  json` and a meaningful exit code.
- iOS UIKit and SwiftUI variants at the `minimal` architecture, generated,
  built and tested against a simulator in CI.
- The bundled Skill for driving the CLI from an AI agent.
