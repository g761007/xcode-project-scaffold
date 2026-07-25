# Compatibility policy

Which macOS, Xcode and toolchain versions `xscaffold` supports, what "supported"
means, and what the generated project inherits from that.

Every version in this document is a fact about the repository — a CI runner
image, a package manifest, a constant in the validator — not a guess. Where a
version is not verified, it says so.

## What "supported" means

Three tiers, and the difference matters:

| Tier | Meaning |
|---|---|
| **Verified** | Every push runs the full suite on it. A break here fails CI. |
| **Expected to work** | Nothing in the code excludes it, and nothing tests it. A break here is a bug worth reporting, not a broken promise. |
| **Unsupported** | Known not to work, or deliberately outside scope. |

## Running `xscaffold`

| | Version | Tier |
|---|---|---|
| macOS | 14 (Sonoma) or later | 14 expected to work; **26 verified** — CI runs `macos-26` |
| Architecture | Apple silicon and Intel | Release binaries are universal; `lipo` proves both slices before publishing |
| Xcode | 26.x | **Verified** — 26.4 at the time of writing |

The macOS floor is the package manifest's (`.macOS(.v14)`), so it applies to
the released binary as well as to a source build. It is a floor, not a target:
CI only ever runs the newest image GitHub offers, so macOS 14 and 15 are
"expected to work" rather than verified.

Xcode is required because `xscaffold` generates Xcode projects and
`--validate-build` drives `xcodebuild`. Only `doctor` and the read-only
commands work without it.

## Building from source

| | Version | Tier |
|---|---|---|
| Swift toolchain | 6.0 or later | **Verified** — `swift-tools-version: 6.0`, Swift 6 language mode |

## External tools

`xscaffold` calls these as subprocesses and does not vendor any of them.

| Tool | Required when | Version |
|---|---|---|
| `git` | always, unless `--skip-git` | Any. No feature newer than `git init --initial-branch` is used |
| `xcodegen` | always, unless `--skip-generate` | **Unpinned.** CI installs whatever Homebrew serves |
| `pod` | the configuration reads pods, without Bundler | **Unpinned** |
| `bundle` | the configuration reads pods, with Bundler | **Unpinned** |
| `xcodebuild` | `--validate-build`, and the generated project's `make build` | Ships with Xcode |
| `swiftlint`, `swiftformat` | the generated project's `make lint` only | **Unpinned** |

**No external tool version is pinned, and that is deliberate for the tool while
being configurable for the project.** `xscaffold` itself takes whatever is
installed: pinning XcodeGen would mean shipping a version that goes stale
between releases. A *generated project* can pin its CocoaPods, because that is a
team decision with a right answer — `dependencyManagement.cocoapods.bundler`
writes a `Gemfile` and installs through `bundle exec`, so every machine and
every CI run resolve the same one ([cocoapods.md](cocoapods.md)).

`doctor` reports what it finds, and requires only what the configuration in
front of it actually needs.

## What a generated project targets

These are the project's versions, not the tool's, and they are the floors
validation enforces.

| | Floor | Default | Why |
|---|---|---|---|
| iOS | 15.0 | 18.0 | The floor is Apple's `RecommendedDeploymentTarget` on the Xcode 26 SDK; the default is one major release back — a defensible floor for a new project, not the newest possible one |
| macOS | 11.0 | 15.0 | Same |

A configuration below the floor is `XS0007` — a capability boundary, not a
permanent error: the floor is xscaffold's own, and moves when the templates
start supporting older releases.

**Some content raises the floor above the project's.** The SwiftUI MVVM example
uses `@Observable`, which needs iOS 17 / macOS 14, so that combination is
`XS0014` below those versions — refused before anything is written rather than
generating a project that cannot compile. The UIKit and AppKit examples observe
through a closure and work at the floor. This is the shape to expect from future
template content: a rule that names the content, not one that raises the floor
for every project.

## Schema versions

`schemaVersion` is a claim, and a document stating a version this binary does
not understand is refused as `SCHEMA_VERSION_UNSUPPORTED` before anything reads
it. `xscaffold capabilities` lists the versions a given binary accepts, and is
the only source worth consulting — a document that decodes is one the binary
read in full.

Retiring a schema version is a breaking change under the
[deprecation policy](deprecation-policy.md).

## What changes at 1.0

Nothing in this document is a promise during `0.x`; the README says so at the
top. From 1.0:

- Raising the macOS floor for `xscaffold` itself is a major-version change.
- Raising the floor a *generated project* may target is a minor-version change
  announced as a deprecation, because it refuses configurations that used to
  work.
- Dropping a schema version is a major-version change.
- Adding an external tool to the required set is a minor-version change,
  announced — a new required tool breaks every machine that does not have it.

## Reporting an incompatibility

Open an issue with the output of `xscaffold doctor --output json` and
`xscaffold --version`. Those two answer most of the questions a version report
raises without a round trip.
