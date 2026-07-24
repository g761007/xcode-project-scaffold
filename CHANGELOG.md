# Changelog

All notable changes to `xscaffold` are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

`xscaffold` uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html), but
the `0.x` series makes **no compatibility promise**: the `scaffold.yml` schema,
the CLI contract, the JSON output and the exit codes may change without a
migration path until `1.0` (see the README).

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
