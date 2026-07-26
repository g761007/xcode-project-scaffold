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

Seven commands work: `new` (interactive, preview-first), `generate`
(non-interactive, from a `scaffold.yml`), `validate`, `plan`, `doctor`,
`capabilities` and `config example`. Four variants — iOS UIKit and SwiftUI,
macOS SwiftUI and AppKit — are generated, built and tested on every push, plain
and with an MVVM (or, on iOS UIKit, MVVM-C) example, as are the `standard` and
`production` presets, each at the deployment target its own contents require; a
separate job checks that generated sources pass the linters they ship with. The
Skill an agent drives all of this with is in
[`Skills/xcode-project-scaffold/`](Skills/xcode-project-scaffold/).

## ⚠️ Stability: none during 0.x

The `scaffold.yml` schema, the CLI contract, the JSON output format and the
error codes **may change without notice, and without a migration path, for the
entire 0.x series.** Do not build automation against them yet.

What those guarantees will be is already written down —
[the deprecation policy](docs/deprecation-policy.md) says what counts as a
breaking change and how much warning it gets, and
[the compatibility policy](docs/compatibility-policy.md) says which macOS,
Xcode and toolchain versions are supported. Both describe intent until 1.0
makes them a promise.

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

That brings XcodeGen with it, and installs shell completions for zsh, bash and
fish. From source instead:

```bash
git clone https://github.com/g761007/xcode-project-scaffold.git
cd xcode-project-scaffold
make install          # swift build -c release, then copy to ~/.local/bin
```

Override the destination with `make install PREFIX=/usr/local`. A source build
reports its version as `0.0.0-dev` — the release number is stamped from the
release tag, so only tagged builds carry one. Release binaries are universal
(Apple silicon + Intel), published on
[GitHub Releases](https://github.com/g761007/xcode-project-scaffold/releases)
with a SHA256 alongside, and smoke-tested — the published archive itself, not
the checkout — before the release goes out.

Homebrew is the supported path, and neither of the two above needs anything
done about Gatekeeper. Downloading that archive in a browser does: the binary
is not signed with a Developer ID, so macOS refuses it once until
`xattr -d com.apple.quarantine ./xscaffold`. The
[compatibility policy](docs/compatibility-policy.md#distribution-and-code-signing)
explains the difference and why signing is deferred.

Completions for any other installation, and the rest of the CLI surface, are in
[the CLI reference](docs/cli-reference.md).

## Usage

```bash
xscaffold new MyApp                           # create a project interactively
xscaffold generate                            # create one from ./scaffold.yml
xscaffold validate scaffold.yml               # check a configuration
xscaffold plan --config scaffold.yml          # show what generate would create
xscaffold doctor                              # check the tools generation needs
xscaffold capabilities                        # show what this version can generate
xscaffold config example > scaffold.yml       # print a configuration to start from
```

Two independent choices run through all of them:

- a **variant** — `ios-uikit`, `ios-swiftui`, `macos-swiftui`, `macos-appkit` —
  the platform and the interface;
- a **preset** — `minimal`, `standard`, `production` — how much project comes
  with it.

```bash
xscaffold new MyApp --variant ios-swiftui --preset standard --yes
```

Execution behaviour lives in flags, never in `scaffold.yml` — the configuration
file describes the *project*, not a particular run. Every command, every flag
and every exit code is in [the CLI reference](docs/cli-reference.md).

### A minimal `scaffold.yml`

```yaml
project:
  name: MyApp
  bundleIdentifier: com.example.myapp

interface:
  primary: swiftui
```

Three fields are required; everything else has a default, and a preset supplies
what you leave out. `xscaffold plan --config scaffold.yml --resolved-config`
shows what an omitted field will actually be. Every field is documented in
[the configuration reference](docs/configuration.md).

## Documentation

| Document | Purpose |
|---|---|
| [docs/getting-started.md](docs/getting-started.md) | Install to first project, both ways |
| [docs/cli-reference.md](docs/cli-reference.md) | Every command, flag, exit code and JSON field |
| [docs/configuration.md](docs/configuration.md) | Every `scaffold.yml` field, default and validation code |
| [docs/presets.md](docs/presets.md) | What each preset brings, and how overrides resolve |
| [docs/templates.md](docs/templates.md) | What each variant generates |
| [docs/architecture.md](docs/architecture.md) | `minimal`, `mvvm`, `mvvm-c` and their examples |
| [docs/dependencies.md](docs/dependencies.md) | Swift packages |
| [docs/cocoapods.md](docs/cocoapods.md) | Podfile, private specs repos, Bundler, the workspace rule |
| [docs/agent-workflow.md](docs/agent-workflow.md) | Driving it from an AI agent |
| [docs/development.md](docs/development.md) | Working on xscaffold itself |
| [docs/release.md](docs/release.md) | Cutting a release |
| [docs/contracts.md](docs/contracts.md) | What each frozen contract contains, and which test holds it |
| [docs/contract-review.md](docs/contract-review.md) | Why each contract says what it says, decided before the freeze |
| [docs/deprecation-policy.md](docs/deprecation-policy.md) | What counts as a breaking change, and how much warning it gets |
| [docs/compatibility-policy.md](docs/compatibility-policy.md) | Which macOS, Xcode and toolchain versions are supported |
| [docs/security-review.md](docs/security-review.md) | What a hostile scaffold.yml can and cannot do |
| [CONTEXT.md](CONTEXT.md) | Project glossary. Read before introducing new terminology |
| [docs/adr/](docs/adr/) | Architecture decision records |
| [docs/plans/](docs/plans/) | Scope, schema, roadmap, and what is explicitly excluded |
| [examples/](examples/) | Four `scaffold.yml` files to start from, each validated by a test |
| [Skills/xcode-project-scaffold/](Skills/xcode-project-scaffold/) | The bundled Skill, and the field reference it points at |

## Examples and demo

[`examples/`](examples/) holds four `scaffold.yml` files, each a project someone
might actually be starting — the smallest file that generates anything, a UIKit
app with a coordinator and packages, a preset with two fields overridden against
it, and the enterprise CocoaPods configuration. They are files edited down to
what was chosen, not `config example`'s resolved output, and a test validates
and plans every one of them.

Two recordings of the real binary live in [`docs/demo/`](docs/demo/):
[`new-preview.txt`](docs/demo/new-preview.txt) is the interactive flow through
the Configuration Preview to Save-and-exit, and
[`new-preset.txt`](docs/demo/new-preset.txt) is the same project in one line
with `--preset standard --yes`. Regenerate both with `Scripts/record-demo.sh`
after changing a flow, so the demos and the binary cannot drift apart.

## Contributing

```bash
make build && make test && make lint
```

[`docs/development.md`](docs/development.md) covers the codebase, the test
layout and the checks; [`CONTRIBUTING.md`](CONTRIBUTING.md) covers the workflow
and pull-request conventions; [`SECURITY.md`](SECURITY.md) covers how to report
a vulnerability.

## License

[MIT](LICENSE) © 2026 Daniel Hsieh
