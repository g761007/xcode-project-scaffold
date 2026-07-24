# xcode-project-scaffold

Create a new Xcode project reproducibly, from a single version-controlled configuration file.

```text
scaffold.yml  →  xscaffold init  →  a project that builds, tests and lints
```

---

## ⚠️ Status: early — five commands work

`init`, `new`, `validate`, `plan` and `doctor` are implemented, with
`--output json` (bar the interactive `new`) and the exit codes below. The iOS
variants — UIKit and SwiftUI — are generated, built and tested against a
simulator on every push, plain and with an MVVM or MVVM-C example; a separate
job checks that generated sources pass the linters they ship with. The Skill an
agent drives all of this with is in
[`Skills/xcode-project-scaffold/`](Skills/xcode-project-scaffold/).

v0.2 adds the MVVM and MVVM-C architectures and the interactive `new` command.

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

It is designed to be driven four ways:

```bash
xscaffold init --preset ios-uikit MyApp        # presets
xscaffold init --config scaffold.yml           # declarative
xscaffold new                                  # interactive — a few questions
                                               #   at the terminal
                                               # or by an AI agent, via the
                                               # bundled Skill, which writes
                                               # scaffold.yml and calls the CLI
```

The machine-readable path is a first-class use case, not an afterthought: every
command but the interactive `new` supports `--output json`, and all of them
return a meaningful exit code.

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
xscaffold init MyApp --preset ios-uikit       # create a project
xscaffold new                                 # create one interactively
xscaffold validate scaffold.yml               # check a configuration
xscaffold plan MyApp --preset ios-uikit       # show what init would create
xscaffold doctor                              # check the tools init needs
```

```text
--config <path>        a scaffold.yml to generate from
--preset <name>        ios-uikit or ios-swiftui
--destination <path>   where to create the project (default: ./<name>)
--output <text|json>   how to report the result
--dry-run              show what init would create, and stop
--force                write into a destination that is not empty
--skip-git             do not create a git repository
--skip-generate        do not run XcodeGen
--validate-build       build the generated project before reporting success
```

`plan` and `init --dry-run` are the same implementation under two names, and
take the same options, so a preview cannot disagree with the run it previews.

`doctor` separates what a default `init` cannot do without — `git` and
`xcodegen` — from what only the generated project needs: `xcodebuild` for
`make test`, `swiftformat` and `swiftlint` for `make lint`. Only a missing
requirement exits 10; the rest are reported and shrugged at.

Pass exactly one of `--config` or `--preset`. The positional name sets
`project.name`; with `--preset` it is required, because a preset says nothing
about the project's identity. A preset derives the bundle identifier as
`com.example.<name>` — it is written into the generated `scaffold.yml`, where
you can change it. Use `--config` when it has to be right from the start.

Execution behaviour lives in flags, never in `scaffold.yml` — the configuration
file describes the *project*, not a particular run.

### Creating a project interactively

`xscaffold new` asks for the name, bundle identifier, interface, architecture,
whether to include the pattern's example, and the environments, then generates
the project through the same pipeline `init` runs. It offers every choice and
lets `validate` decide, re-asking a question when a combination is refused — it
holds no rules of its own.

`new` needs a terminal; for a scriptable run, use `init`. It shares `init`'s
`--destination`, `--force`, `--skip-git`, `--skip-generate` and
`--validate-build`; `--yes` skips the final confirmation. Cancelling — a "no" at
the confirmation, or Ctrl-C — exits `130` and writes nothing.

Generating into a destination that already exists and is not empty fails with
exit code 6; `--force` writes into it anyway, replacing files the plan produces
and leaving everything else alone. **xscaffold only ever deletes what it
created:** if a run fails after creating the destination, the destination is
removed; if the destination was already there, it is left as it is and the
error says so.

### Machine-readable output

`--output json` puts one JSON document on stdout and nothing else; anything a
person would read goes to stderr. Failures produce a document too — that is
when a caller needs it most:

```console
$ xscaffold validate scaffold.yml --output json
{"command":"validate","exitCode":0,"issues":[],"ok":true}

$ xscaffold doctor --output json | jq '.checks[] | select(.found == false)'
```

`ok`, `command` and `exitCode` are always present, and `message` on failure.
`issues`, `plan`, `checks` and `destination` appear only when that command has
them to report — an absent key, never `null`. `plan` carries file paths and
sizes, not file contents.

### Exit codes

```text
0   success                        6   file conflict
1   unexpected failure             7   generation failure
2   invalid CLI arguments          8   external command failure
3   configuration parsing failure  9   build validation failure
4   configuration validation       10  environment requirement missing
5   template resolution failure    130 cancelled (new)
```

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

For an architecture with a worked example, set `architecture.pattern` to `mvvm`
or `mvvm-c` (`mvvm-c` on UIKit only). `architecture.includeExample` controls
whether the example is generated: left out it follows the pattern, so `mvvm`
gets the example without stating it; set `false` for the structure and notes
without the example code.

Note that `language.languageMode` is Xcode's `SWIFT_VERSION` build setting — a
*language mode*, whose only valid values are `5` and `6`. It is not a compiler
or toolchain version.

## Development

```bash
make build            # swift build
make test             # swift test
make e2e              # generate, build and test both variants
make lint             # swiftformat --lint and swiftlint --strict
make format           # apply formatting in place
make install          # release build, installed to $PREFIX/bin
```

`make lint` needs `swiftlint` and `swiftformat` on the PATH
(`brew install swiftlint swiftformat`). CI installs them itself.

`make e2e` creates a project from each preset with the freshly built binary —
which runs XcodeGen as part of `init` — then builds and tests it against a
simulator. It needs `xcodegen` on the PATH and a git identity, and it prints
which simulator it chose, for the reason below. CI runs it on every push.

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
| [`CHANGELOG.md`](CHANGELOG.md) | What changed in each release. |
| [`CONTEXT.md`](CONTEXT.md) | Project glossary. Read before introducing new terminology. |
| [`docs/plans/xcode-project-scaffold-plan.md`](docs/plans/xcode-project-scaffold-plan.md) | Scope, schema, milestones, and what is explicitly excluded. |
| [`docs/adr/`](docs/adr/) | Architecture decision records. |
| [`Skills/xcode-project-scaffold/`](Skills/xcode-project-scaffold/) | The bundled Skill, and the `scaffold.yml` field reference it points at. |

## License

[MIT](LICENSE) © 2026 Daniel Hsieh
