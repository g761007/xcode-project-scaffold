# xcode-project-scaffold

Create a new Xcode project reproducibly, from a single version-controlled configuration file.

```text
scaffold.yml  →  xscaffold init  →  a project that builds, tests and lints
```

---

## ⚠️ Status: early — `init` works, the other commands do not

`xscaffold init` creates a project end to end: sources, `project.yml`,
`scaffold.yml`, lint and format configuration, a `Makefile`, a git repository
with an initial commit, and a generated `.xcodeproj`. Both v0.1 variants —
UIKit and SwiftUI — have been checked by hand to lint, build and test after
generation, on Xcode 26.4.1; CI does not run that check yet.

`validate`, `plan`, `doctor`, `--output json` and `--dry-run` do **not** exist
yet. Everything below marked *(planned)* describes the intended v0.1.

Track the scope and milestones in
[`docs/plans/xcode-project-scaffold-plan.md`](docs/plans/xcode-project-scaffold-plan.md).

## ⚠️ Stability: none during 0.x

The `scaffold.yml` schema, the CLI contract, the JSON output format and the
error codes **may change without notice, and without a migration path, for the
entire 0.x series.** Do not build automation against them yet.

Stability guarantees, a Homebrew tap and a template compatibility policy are
deferred until 1.0.

---

## What it is

`xscaffold` turns a declarative description of an Xcode project into a real
one — source files, `project.yml`, lint and format configuration, a `Makefile`,
build environments and a git repository — and guarantees that the same
configuration produces the same project.

It is designed to be driven three ways:

```bash
xscaffold init --preset ios-uikit MyApp        # presets
xscaffold init --config scaffold.yml           # declarative
                                               # or by an AI agent, via the
                                               # bundled Skill, which writes
                                               # scaffold.yml and calls the CLI
```

The machine-readable path is a first-class use case, not an afterthought:
commands return meaningful exit codes, and `--output json` is planned for all of
them.

## What it deliberately does not do

The tool's boundary is **project creation**. It does not manage projects it did
not create, and it does not manage a project after creation:

- No regeneration, no template upgrades, no config migration
- No ownership manifest or file checksums
- No `inspect` / `import` of existing projects
- No `add feature` / `add package` / `add integration`
- No Objective-C or mixed-language project creation

Once a project is generated, `project.yml` becomes its source of truth and
`xscaffold` steps out of the way. `scaffold.yml` remains only as a record of
how the project was created.

The reasoning, and what it costs, is recorded in
[ADR-0001](docs/adr/0001-scaffold-yml-as-birth-certificate.md).

---

## Requirements

| | |
|---|---|
| macOS | Apple silicon or Intel, with Xcode installed |
| Xcode | 26.x (developed and tested against 26.4) |
| Swift toolchain | 6.0 or later (developed and tested against 6.3) |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | required at generation time; `xscaffold` fails with exit code 10 if it is missing |

`xscaffold` calls XcodeGen as a subprocess and does not vendor it. Generated
projects also expect XcodeGen to be available, since `.xcodeproj` is a derived
artifact and is git-ignored.

## Installation

```bash
git clone https://github.com/g761007/xcode-project-scaffold.git
cd xcode-project-scaffold
make install          # swift build -c release, then copy to ~/.local/bin
```

Override the destination with `make install PREFIX=/usr/local`.

There is no pre-built binary distribution during 0.x. Binaries downloaded from
the internet are quarantined by Gatekeeper unless signed with a Developer ID
and notarised, which is disproportionate at this stage. Building from source
avoids the problem entirely, and the target audience already has a Swift
toolchain.

## Usage

```bash
xscaffold init MyApp --preset ios-uikit       # from a preset
xscaffold init --config scaffold.yml          # from a configuration file
```

```text
--config <path>        a scaffold.yml to generate from
--preset <name>        ios-uikit or ios-swiftui
--destination <path>   where to create the project (default: ./<name>)
--force                write into a destination that is not empty
--skip-git             do not create a git repository
--skip-generate        do not run XcodeGen
```

Pass exactly one of `--config` or `--preset`. The positional name sets
`project.name`; with `--preset` it is required, because a preset says nothing
about the project's identity. A preset derives the bundle identifier as
`com.example.<name>` — it is written into the generated `scaffold.yml`, where
you can change it. Use `--config` when it has to be right from the start.

Execution behaviour lives in flags, never in `scaffold.yml` — the configuration
file describes the *project*, not a particular run.

Generating into a destination that already exists and is not empty fails with
exit code 6; `--force` writes into it anyway, replacing files the plan produces
and leaving everything else alone. **xscaffold only ever deletes what it
created:** if a run fails after creating the destination, the destination is
removed; if the destination was already there, it is left as it is and the
error says so.

### Planned commands

```bash
xscaffold validate <path>     # validate a scaffold.yml
xscaffold plan                # preview the generation plan without writing
xscaffold doctor              # check that required tools are available
```

…together with `--output <text|json>`, `--dry-run`, `--validate-build` and
`--yes`.

### Minimal `scaffold.yml`

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

environments: []

quality:
  swiftlint: true
  swiftformat: true

testing:
  unit: swift-testing

git:
  defaultBranch: main
```

The full field reference is in
[`docs/plans/xcode-project-scaffold-plan.md`](docs/plans/xcode-project-scaffold-plan.md) §4.

Note that `language.languageMode` is Xcode's `SWIFT_VERSION` build setting — a
*language mode*, whose only valid values are `5` and `6`. It is not a compiler
or toolchain version.

## Development

```bash
make build            # swift build
make test             # swift test
make lint             # swiftformat --lint and swiftlint --strict
make format           # apply formatting in place
make install          # release build, installed to $PREFIX/bin
```

`make lint` needs `swiftlint` and `swiftformat` on the PATH
(`brew install swiftlint swiftformat`). CI installs them itself.

Integration tests *(planned)* will generate both variants and run
`xcodegen generate`, `xcodebuild build` and `xcodebuild test` against them.

When invoking `xcodebuild` locally, **always pass an unambiguous destination.**
A device name alone matches several simulators across installed runtimes, and
`xcodebuild` will pick one arbitrarily:

```bash
# ambiguous — do not do this
-destination 'platform=iOS Simulator,name=iPhone 16'

# unambiguous
-destination 'platform=iOS Simulator,name=iPhone 16,OS=18.0'
-destination 'id=<simulator-udid>'
```

---

## Documentation

| Document | Purpose |
|---|---|
| [`CONTEXT.md`](CONTEXT.md) | Project glossary. Read before introducing new terminology. |
| [`docs/plans/xcode-project-scaffold-plan.md`](docs/plans/xcode-project-scaffold-plan.md) | Scope, schema, milestones, and what is explicitly excluded. |
| [`docs/adr/`](docs/adr/) | Architecture decision records. |

## License

[MIT](LICENSE) © 2026 Daniel Hsieh
