# Changelog

All notable changes to `xscaffold` are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

`xscaffold` uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html), but
the `0.x` series makes **no compatibility promise**: the `scaffold.yml` schema,
the CLI contract, the JSON output and the exit codes may change without a
migration path until `1.0` (see the README).

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
