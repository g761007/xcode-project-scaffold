# xcode-project-scaffold

Create a new Xcode project reproducibly, from a single version-controlled
configuration file — with a full preview before anything touches disk.

```bash
brew install g761007/tap/xscaffold
xscaffold new MyApp
```

```text
answer a few questions  →  Configuration Preview  →  Generate / Save / Edit / Cancel
                                                     └→ a project that builds, tests and lints
```

---

## ⚠️ Status: early — preview-first as of v0.4

Six commands work: `new` (interactive, preview-first), `generate`
(non-interactive, from a `scaffold.yml`), `validate`, `plan`, `doctor`, and the
deprecated `init`. Four variants — iOS UIKit and SwiftUI, macOS SwiftUI and
AppKit — are generated, built and tested on every push, plain and with an MVVM
(or, on iOS UIKit, MVVM-C) example; a separate job checks that generated
sources pass the linters they ship with. The Skill an agent drives all of this
with is in [`Skills/xcode-project-scaffold/`](Skills/xcode-project-scaffold/).

## ⚠️ Stability: none during 0.x

The `scaffold.yml` schema, the CLI contract, the JSON output format and the
error codes **may change without notice, and without a migration path, for the
entire 0.x series.** Do not build automation against them yet. Stability
guarantees and a template compatibility policy arrive with 1.0.

---

## What it is

`xscaffold` turns a declarative description of an Xcode project into a real
one — source files, `project.yml`, lint and format configuration, a `Makefile`,
build environments and a git repository — and guarantees that the same
configuration produces the same project.

It is designed to be driven four ways:

```bash
xscaffold new MyApp                            # interactive, preview-first
xscaffold new MyApp --variant ios-uikit --yes  # one line, no questions
xscaffold generate --config scaffold.yml       # declarative, scriptable
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
how the project was created. A destination that already contains a project —
an `.xcodeproj`, an `.xcworkspace`, a `project.yml` or source code — is refused
outright, and no flag can change that.

The reasoning, and what it costs, is recorded in
[ADR-0001](docs/adr/0001-scaffold-yml-as-birth-certificate.md).

---

## Requirements

| | |
|---|---|
| macOS | Apple silicon or Intel, with Xcode installed |
| Xcode | 26.x (developed and tested against 26.4) |
| Swift toolchain | building from source only: 6.0 or later |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | required at generation time; `xscaffold` fails with exit code 10 if it is missing |

`xscaffold` calls XcodeGen as a subprocess and does not vendor it. Generated
projects also expect XcodeGen to be available, since `.xcodeproj` is a derived
artifact and is git-ignored. The Homebrew formula depends on `xcodegen`, so a
brew install brings it along.

## Installation

```bash
brew install g761007/tap/xscaffold
```

Or from source:

```bash
git clone https://github.com/g761007/xcode-project-scaffold.git
cd xcode-project-scaffold
make install          # swift build -c release, then copy to ~/.local/bin
```

Override the destination with `make install PREFIX=/usr/local`. A source build
reports its version as `0.0.0-dev` — the release number is stamped from the
release tag, so only tagged builds carry one.

Release binaries are universal (Apple silicon + Intel), published on
[GitHub Releases](https://github.com/g761007/xcode-project-scaffold/releases)
with a SHA256 alongside, and smoke-tested — the published archive itself, not
the checkout — before the release goes out.

## Usage

```bash
xscaffold new MyApp                           # create a project interactively
xscaffold generate                            # create one from ./scaffold.yml
xscaffold validate scaffold.yml               # check a configuration
xscaffold plan --config scaffold.yml          # show what generate would create
xscaffold doctor                              # check the tools generation needs
xscaffold capabilities                        # show what this version can generate
```

```text
--variant <name>       ios-uikit, ios-swiftui, macos-swiftui or macos-appkit —
                       answers the platform and interface questions (new)
--config <path>        a scaffold.yml to generate from (default: ./scaffold.yml)
--destination <path>   where to create the project (default: ./<name>)
--output <text|json>   how to report the result
--yes, -y              skip the confirmation; with --variant, skip every question
--advanced             also ask about the fields most projects leave at defaults (new)
--open                 open the generated project on success (new)
--files                list every file and command in the plan (plan)
--resolved-config      show the configuration with every default resolved (plan)
--force                write into a non-empty destination without project markers
--skip-git             do not create a git repository
--skip-generate        do not run XcodeGen
--validate-build       build the generated project before reporting success
```

`plan` shares `generate`'s inputs and its implementation, so a preview cannot
disagree with the run it previews.

`doctor` separates what generation cannot do without — `git` and `xcodegen` —
from what only the generated project needs: `xcodebuild` for `make test`,
`swiftformat` and `swiftlint` for `make lint`. Only a missing requirement exits
10; the rest are reported and shrugged at.

Execution behaviour lives in flags, never in `scaffold.yml` — the configuration
file describes the *project*, not a particular run.

### Creating a project interactively

`xscaffold new` asks for the platform, name, bundle identifier, interface,
architecture, whether to include the pattern's example, and the environments —
then stops at a **Configuration Preview**: the resolved settings, the file
count, any files a forced run would overwrite, the commands that will run, and
a menu.

```text
What next?
  1) Generate project
  2) Save scaffold.yml and exit
  3) Edit configuration
  4) Show complete file plan
  5) Show resolved configuration
  6) Cancel
```

Nothing touches disk until an option says otherwise. **Generate** runs the plan
it previewed. **Save** writes only `scaffold.yml` — the same bytes generating
would have written — for review, version control, or a later `generate`.
**Edit** re-asks one section (project, platform and interface, architecture, or
environments) and comes back to a fresh preview, as many rounds as it takes.
The two **Show** options print the full file list and the fully-resolved
configuration, then return to the menu. **Cancel** — or Ctrl-C, or ended
input, anywhere — exits `130` and writes nothing.

`--variant` answers the platform and interface questions from the command line;
with `--yes` as well there is no question left standing:

```bash
xscaffold new MyApp --variant ios-uikit --yes   # one line, no terminal needed
```

`--advanced` appends questions for the fields most projects leave at their
defaults: organization name, deployment target, unit test framework, the
SwiftLint and SwiftFormat switches, and the git default branch. Every interface
is offered on every platform; `validate` decides, and a refused combination —
UIKit on macOS, AppKit on iOS — re-asks the question rather than being filtered
out, so the prompt holds no rules of its own.

### The save-now, generate-later flow

```bash
xscaffold new MyApp            # answer, review the preview, choose Save
cd MyApp
# edit scaffold.yml, commit it, have it reviewed…
xscaffold plan --config scaffold.yml --destination .
xscaffold generate --destination .
```

`generate` reads an existing `scaffold.yml` (`--config`, defaulting to
`./scaffold.yml`), shows a summary — including anything it would overwrite —
and asks before writing. `--yes` skips the question but not the validation, the
plan, or the destination rules; without a terminal and without `--yes` it
refuses rather than hangs, so a forgotten flag cannot stall a pipeline:

```bash
xscaffold generate --yes --output json         # CI and agents
```

### Where generation may land

- **Always allowed:** a missing directory, an empty one, or one holding only a
  `scaffold.yml` (how Save leaves it).
- **`--force` moves in:** a non-empty directory without project markers — the
  GitHub-starter clone with README, LICENSE and `.git`. What would be
  overwritten is listed in the plan and the preview first; nothing else is
  touched, and the directory is never emptied.
- **Never:** a directory containing an `.xcodeproj`, `.xcworkspace`,
  `project.yml` or top-level Swift source. `OUTPUT_DIRECTORY_HAS_PROJECT`,
  exit 6, no flag bypasses it — xscaffold creates new projects and does not
  update existing ones.

**xscaffold only ever deletes what it created:** files are staged beside the
destination and moved in atomically; if a run fails after creating the
destination, the destination is removed; if it was already there, it is left
as it is and the error says so.

### Dependencies

`dependencyManagement.mode` is `none`, `spm`, `cocoapods` or `mixed` — SPM is
the default recommendation; CocoaPods exists for the teams that need it, and
`mixed` runs both while refusing the same library arriving through each.

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

Packages land in `project.yml` and resolve on first build. Pods state exactly
one source each — `version`, `path`, or `git` with one of `tag`, `branch` or
`commit` — and xscaffold writes the Podfile, runs `pod install` after XcodeGen,
verifies the workspace it produced, and drives Build, Test and Open through
that workspace from then on. `doctor` requires CocoaPods exactly when the
configuration reads pods.

### Project essentials

- **UI tests** — `testing.ui.enabled` grows a ui-testing target with a launch
  test and a smoke test (`launchPerformanceTest` adds a measured launch),
  configured apart from `testing.unit`.
- **Environment values** — `environments[].values` become per-configuration
  `.xcconfig` files, reach the Info.plist as `$(KEY)` references, and are read
  in code through the generated `AppConfiguration` (`API_BASE_URL` reads as
  `AppConfiguration.apiBaseURL`).
- **Secrets** — `secrets.keys` may state a name and an obviously-fake example,
  and nothing else; `Secrets.example.xcconfig` is the committed record, the
  real `Secrets.xcconfig` starts as a copy and is git-ignored.
- **Localization** — `localization.languages` generates one
  `Resources/<language>.lproj/Localizable.strings` per shipped language.
- **Machine-readable capabilities** — `xscaffold capabilities --output json`
  lists what this binary actually generates, sourced from the same sets the
  validator enforces. Generated `scaffold.yml` files carry a
  `yaml-language-server` annotation pointing at
  [`Schemas/scaffold.schema.json`](Schemas/scaffold.schema.json), so editors
  validate while you type.

### The deprecated `init`

`init` still works but warns on every run, and goes away in v0.6:

```text
init --config existing.yml     →   generate --config existing.yml
init MyApp --preset ios-uikit  →   new MyApp --variant ios-uikit --yes
```

The reasoning is recorded in
[ADR-0007](docs/adr/0007-init-retires-preset-becomes-variant.md).

### Machine-readable output

`--output json` puts one JSON document on stdout and nothing else; anything a
person would read goes to stderr. Failures produce a document too — that is
when a caller needs it most:

```console
$ xscaffold validate scaffold.yml --output json
{"command":"validate","exitCode":0,"issues":[],"ok":true}

$ xscaffold plan --config scaffold.yml --resolved-config --output json \
    | jq .resolvedConfiguration.product

$ xscaffold doctor --output json | jq '.checks[] | select(.found == false)'
```

`ok`, `command` and `exitCode` are always present, and `message` on failure.
`issues`, `plan`, `resolvedConfiguration`, `checks`, `capabilities` and
`destination` appear
only when that command has them to report — an absent key, never `null`.
`plan` carries file paths and sizes, not file contents, plus an `overwrites`
list when a forced run would replace existing files.

### Exit codes

```text
0   success                        6   file conflict
1   unexpected failure             7   generation failure
2   invalid CLI arguments          8   external command failure
3   configuration parsing failure  9   build validation failure
4   configuration validation       10  environment requirement missing
5   template resolution failure    130 cancelled (new, generate)
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

Every field but `project.name`, `project.bundleIdentifier` and
`interface.primary` has a default — `plan --resolved-config` shows what an
omitted field will actually be.

For an architecture with a worked example, set `architecture.pattern` to `mvvm`
or `mvvm-c` (`mvvm-c` on UIKit only). `architecture.includeExample` controls
whether the example is generated: left out it follows the pattern, so `mvvm`
gets the example without stating it; set `false` for the structure and notes
without the example code.

Note that `language.languageMode` is Xcode's `SWIFT_VERSION` build setting — a
*language mode*, whose only valid values are `5` and `6`. It is not a compiler
or toolchain version.

## Demo

A recording of the interactive preview flow lives in
[`docs/demo/new-preview.txt`](docs/demo/new-preview.txt) — regenerate it with
`Scripts/record-demo.sh` after changing the flow, so the demo and the binary
cannot drift apart.

## Development

```bash
make build            # swift build
make test             # swift test
make e2e              # generate, build and test every variant
make lint             # swiftformat --lint and swiftlint --strict
make format           # apply formatting in place
make install          # release build, installed to $PREFIX/bin
```

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the development workflow, test
layout and pull-request conventions, and [`SECURITY.md`](SECURITY.md) for how
to report a vulnerability.

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
| [`docs/plans/`](docs/plans/) | Scope, schema, roadmap, and what is explicitly excluded. |
| [`docs/adr/`](docs/adr/) | Architecture decision records. |
| [`Skills/xcode-project-scaffold/`](Skills/xcode-project-scaffold/) | The bundled Skill, and the `scaffold.yml` field reference it points at. |

## License

[MIT](LICENSE) © 2026 Daniel Hsieh
