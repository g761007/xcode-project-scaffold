# xcode-project-scaffold

Create a new Xcode project reproducibly, from a single version-controlled configuration file.

```text
scaffold.yml  →  xscaffold init  →  a project that builds, tests and lints
```

---

## ⚠️ Status: planning — no implementation yet

This repository currently contains **design documents only**. There is no
`Package.swift`, no executable, and nothing to install. Everything under
"Usage" and "Development" below describes the intended v0.1 and does not work
today.

Track the intended scope and milestones in
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

The machine-readable path is a first-class use case, not an afterthought: every
command supports `--output json` and returns meaningful exit codes.

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
| Swift toolchain | 6.3 or later |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | required at generation time; `xscaffold` fails with exit code 10 if it is missing |

`xscaffold` calls XcodeGen as a subprocess and does not vendor it. Generated
projects also expect XcodeGen to be available, since `.xcodeproj` is a derived
artifact and is git-ignored.

## Installation *(planned)*

```bash
git clone https://github.com/<owner>/xcode-project-scaffold.git
cd xcode-project-scaffold
make install          # swift build -c release, then copy to ~/.local/bin
```

There is no pre-built binary distribution during 0.x. Binaries downloaded from
the internet are quarantined by Gatekeeper unless signed with a Developer ID
and notarised, which is disproportionate at this stage. Building from source
avoids the problem entirely, and the target audience already has a Swift
toolchain.

## Usage *(planned)*

```bash
xscaffold init [name]         # create a project
xscaffold validate <path>     # validate a scaffold.yml
xscaffold plan                # preview the generation plan without writing
xscaffold doctor              # check that required tools are available
```

Common flags:

```text
--config <path>      --preset <name>      --destination <path>
--output <text|json> --dry-run            --force
--skip-git           --skip-generate      --validate-build
```

Execution behaviour lives in flags, never in `scaffold.yml` — the configuration
file describes the *project*, not a particular run.

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

## Development *(planned)*

```bash
swift build           # build
swift test            # unit and contract tests
make install          # install to ~/.local/bin
```

Integration tests generate both variants and run `xcodegen generate`,
`xcodebuild build` and `xcodebuild test` against them. They run in CI on every
push.

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
