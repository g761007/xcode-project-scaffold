# Getting started

From nothing to a project that builds, in about five minutes.

## Install

```bash
brew install g761007/tap/xscaffold
```

That brings XcodeGen with it, and installs shell completions for zsh, bash and
fish. From source instead:

```bash
git clone https://github.com/g761007/xcode-project-scaffold.git
cd xcode-project-scaffold
make install          # release build, copied to ~/.local/bin
```

A source build reports its version as `0.0.0-dev`; only tagged builds carry a
release number.

## Check the machine

```bash
xscaffold doctor
```

`doctor` separates what generation cannot do without — `git` and `xcodegen` —
from what only the generated project needs later: `xcodebuild` for `make test`,
`swiftformat` and `swiftlint` for `make lint`. Only a missing requirement exits
`10`; the rest are reported and shrugged at.

## The first project, interactively

```bash
xscaffold new Bookshelf
```

It asks for the platform, the name, the bundle identifier, the interface, the
architecture, whether to include that architecture's example, and the build
environments — then stops at the **Configuration Preview** and waits:

```text
What next?
  1) Generate project
  2) Save scaffold.yml and exit
  3) Edit configuration
  4) Show complete file plan
  5) Show resolved configuration
  6) Cancel
```

Nothing has touched disk yet. **Generate** writes the project; **Save** writes
only the `scaffold.yml`, for a project you want reviewed before it exists;
**Edit** goes back to any single answer and returns here; **Cancel** leaves
nothing behind. A full transcript is in
[`demo/new-preview.txt`](demo/new-preview.txt).

Skip the questions when there is nothing to ask:

```bash
xscaffold new Bookshelf --variant ios-swiftui --preset standard --yes
```

A **variant** is the platform and the interface; a **preset** is how much
project comes with it. They are independent — see [presets](presets.md) and
[templates](templates.md).

## The first project, from a file

The path a script or an agent takes, and the one worth using as soon as the
project has anything to say about itself:

```bash
xscaffold config example --preset standard > scaffold.yml
$EDITOR scaffold.yml                       # replace the placeholder identity
xscaffold validate scaffold.yml
xscaffold plan --config scaffold.yml --files
xscaffold generate --config scaffold.yml --yes
```

`config example` prints a document with every field resolved, so you can read
what you are about to get before you get it. [`examples/`](../examples/) holds
four files edited down to what someone actually chose, which is closer to what
a committed `scaffold.yml` looks like.

## Save now, generate later

The two paths meet here. `new`'s **Save `scaffold.yml` and exit** writes the
configuration and nothing else — the same bytes generating would have written —
so a project can be reviewed, committed and discussed before it exists:

```bash
xscaffold new Bookshelf            # answer, review the preview, choose Save
cd Bookshelf
$EDITOR scaffold.yml               # …edit, commit, have it reviewed
xscaffold plan --config scaffold.yml --destination .
xscaffold generate --destination .
```

`--destination .` is needed on both: without it `generate` would create
`./Bookshelf` *inside* the directory you just changed into. A directory holding
only a `scaffold.yml` is the one non-empty destination that is written into
without `--force` — that is exactly what this flow leaves behind.

## What you get

```text
Bookshelf/
├── App/                  sources for the chosen interface and architecture
├── Tests/                a unit test target that compiles and passes
├── Resources/            asset catalogue, with an app icon and accent colour
├── project.yml           XcodeGen's input — the project's source of truth
├── scaffold.yml          a record of how this project was created
├── Makefile              generate, build, test, lint, format
├── README.md             what this project is, and how to work on it
├── .swiftlint.yml        }
├── .swiftformat          } configuration the linters actually use
└── .gitignore
```

Plus a git repository with one commit, unless `--skip-git`, and
`Bookshelf.xcodeproj` produced by XcodeGen, unless `--skip-generate`.

There is no `.xcodeproj` in version control by design: it is derived from
`project.yml`, and `make generate` reproduces it.

```bash
cd Bookshelf
make open      # regenerate and open in Xcode
make test
make lint
```

## What happens next

`xscaffold` is finished. `project.yml` is the project's source of truth from
here, and there is no regenerate, upgrade or migrate command — see
[what it deliberately does not do](../README.md#what-it-deliberately-does-not-do)
and [ADR-0001](adr/0001-scaffold-yml-as-birth-certificate.md).

## Where to go next

| | |
|---|---|
| Every command and flag | [cli-reference.md](cli-reference.md) |
| Every `scaffold.yml` field | [configuration.md](configuration.md) |
| How much project a preset brings | [presets.md](presets.md) |
| Swift packages | [dependencies.md](dependencies.md) |
| Pods, private specs repos, Bundler | [cocoapods.md](cocoapods.md) |
| What each variant generates | [templates.md](templates.md) |
| MVVM and MVVM-C | [architecture.md](architecture.md) |
| Driving it from an AI agent | [agent-workflow.md](agent-workflow.md) |
| What may change, and when | [deprecation-policy.md](deprecation-policy.md) |
| Which macOS and Xcode versions work | [compatibility-policy.md](compatibility-policy.md) |
