# Development

Working on `xscaffold` itself. For contributing conventions — branches, commit
messages, what a PR has to carry — see [`CONTRIBUTING.md`](../CONTRIBUTING.md).

## Setup

```bash
git clone https://github.com/g761007/xcode-project-scaffold.git
cd xcode-project-scaffold
make build && make test
```

macOS with Xcode 26.x and a Swift 6 toolchain. `make e2e` additionally needs
`xcodegen`, `cocoapods` and a git identity; `make lint` needs `swiftlint` and
`swiftformat`:

```bash
brew install xcodegen cocoapods swiftlint swiftformat
```

## The Makefile

```bash
make build            # swift build
make test             # swift test
make e2e              # generate, build and test every variant and preset
make lint             # swiftformat --lint and swiftlint --strict
make format           # apply formatting in place
make templates        # re-embed Templates/ into Swift source
make benchmark        # p50/p95 for startup, capabilities and plan
make release          # swift build -c release
make install          # release build, installed to $PREFIX/bin
```

## The shape of the codebase

| Target | What lives there |
|---|---|
| `ScaffoldSchema` | The published contract: configuration, plan, output, error and exit-code types. No behaviour, and no dependencies — it must never reach the file system or spawn a process. |
| `ScaffoldCore` | Everything the tool does: parsing, validation, planning, execution, prompting, rendering. |
| `xscaffold` | The CLI: flags, reporting, and the mapping from failures to exit codes. |

Two seams make the whole tool testable, and every subprocess and every
interactive question goes through them:

- **`ProcessRunner`** — external commands. Tests use `FakeProcessRunner`.
- **`Prompter`** — terminal I/O. Tests use `ScriptedPrompter`.

Nothing in the test suite launches a real tool or needs a real terminal.

## Templates

Templates under `Templates/` are compiled into the binary from a generated Swift
file that is committed. After editing one:

```bash
make templates
git add Sources/ScaffoldCore/Generated/EmbeddedTemplates.swift
```

CI fails if regenerating changes anything, so an edited template with a stale
embedding cannot merge.

Structural differences reach templates as **values**, never as conditionals: a
project with no linters still gets a `lint` target in its `Makefile`, one that
says so. Two templates may not produce the same file — see
[templates.md](templates.md#two-templates-may-not-produce-the-same-file).

To look at generated output with real tools:

```bash
MATERIALISE_ROOT=/tmp/generated swift test --filter MaterialiseTemplates
cd /tmp/generated/SwiftUIMVVMApp && swiftformat --lint . && swiftlint --strict
```

That is what CI's lint job does, and it is why a template that renders but does
not lint clean fails before release rather than after.

## Tests

`swift test` must pass and `make lint` must be clean before a PR is opened.

| Suite | What it checks |
|---|---|
| `ScaffoldSchemaTests` | The wire format: JSON keys, error codes, exit codes, and that the Skill's reference still matches the schema. |
| `ScaffoldCoreTests` | Planning, validation, rendering, execution — against fakes, never the real toolchain. |
| `CommandLineTests` | The real built binary: exit codes, stdout under `--output json`, and what lands on disk. |

Tests assert **external behaviour** — CLI output, exit codes, JSON documents,
files written — not internal call order. Everything that writes passes
`--skip-git --skip-generate`, so the suite passes on a machine with neither
tool installed.

Three suites exist specifically to catch drift that no code diff would show:

- **`SkillReferenceTests`** — every validation code and every allowed value is
  documented in the Skill's reference, and nothing it documents has since been
  removed.
- **`SkillCommandTests`** — every command line the Skill tells an agent to run
  is a command line that exists.
- **`ExampleConfigurationTests`** — every file in [`examples/`](../examples/)
  still validates and still plans.

## The e2e matrix

`make e2e` generates, builds and tests every variant and architecture, the
dependency matrix including CocoaPods, and the presets — each at the deployment
target its own contents require, not the default. It takes about fifty minutes
on CI and needs Xcode, so it is a separate job from `swift test`.

An e2e case belongs at the **floor its configuration imposes**, not at the
default target. A case at the default target hides availability bugs; that is
how a SwiftUI example using `@Observable` shipped against an iOS 15 floor.

## Performance

```bash
make benchmark
```

Reports p50 and p95 for process start, `capabilities`, and `plan` against the
heaviest configuration this version can describe. It is not a CI gate — a
threshold on a shared runner measures the runner — it exists so a change
suspected of costing time can be answered with a number.

## Documentation that has to stay true

| If you change… | Update |
|---|---|
| A CLI flag, exit code or JSON field | [cli-reference.md](cli-reference.md), the contract tests, and `SKILL.md` |
| A `scaffold.yml` field | [configuration.md](configuration.md), `Schemas/scaffold.schema.json`, and the Skill's reference |
| A template | `make templates`, and [templates.md](templates.md) if it adds a file |
| An architectural decision | An ADR in [`adr/`](adr/), and [`CONTEXT.md`](../CONTEXT.md) if it introduces a word |

[`CONTEXT.md`](../CONTEXT.md) is the project glossary. Use its words, and do not
introduce a synonym for something that already has a name.
