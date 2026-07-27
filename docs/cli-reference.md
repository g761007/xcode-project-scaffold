# CLI reference

Seven commands. `xscaffold <command> --help` prints the same information at the
terminal; this page is the whole surface in one place.

Execution behaviour lives in flags, never in `scaffold.yml` — the configuration
file describes the *project*, not a particular run.

## `new`

Create a project by answering a few questions.

```bash
xscaffold new MyApp
xscaffold new MyApp --variant ios-uikit --yes
xscaffold new MyApp --variant ios-swiftui --preset standard --yes
xscaffold new MyApp --variant ios-swiftui --preset production --dependency-manager cocoapods --yes
```

| Flag | Meaning |
|---|---|
| `<name>` | The project name. Asked for if omitted. |
| `--destination <path>` | Where to create it. Defaults to `./<name>`. |
| `--variant <name>` | `ios-uikit`, `ios-swiftui`, `macos-swiftui`, `macos-appkit` — answers the platform and interface questions. |
| `--preset <name>` | `minimal`, `standard`, `production` — how much project comes with it. |
| `--dependency-manager <name>` | `none`, `spm`, `cocoapods`, `mixed` — what reads the packages. Defaults to whatever the preset says. |
| `--yes`, `-y` | Skip the final confirmation. With `--variant`, skip the questions too. |
| `--advanced` | Also ask about the fields most projects leave at their defaults. |
| `--open` | Open the generated project when generation succeeds. |
| `--force` | Write into a destination that is not empty. |
| `--validate-build` | Build the generated project before reporting success. |
| `--skip-git` | Do not create a git repository. |
| `--skip-generate` | Do not run the generator. |
| `--output <text\|json>` | How to report the result. |

Without `--variant`, `--yes` still asks the questions — it only skips the
confirmation. `new` needs a terminal unless both `--variant` and `--yes` are
given; without one it exits `2` and says so rather than hanging on a prompt
nobody can see.

`--dependency-manager` is the same flag [`config example`](#config-example)
takes, and the two produce the same document from the same arguments. It is
worth stating at creation rather than editing afterwards, because the mode
decides the project's shape: whether there is a Podfile, whether builds go
through an `.xcodeproj` or the `.xcworkspace` `pod install` creates, and what
the generated CI workflow runs. Under `--preset production`, choosing
`cocoapods` or `mixed` also pins Bundler and a CocoaPods version — see
[dependencies](dependencies.md).

The interactive flow stops at a **Configuration Preview** with a menu:
generate, save the `scaffold.yml` and exit, edit an answer, show the complete
file plan, show the resolved configuration, or cancel. Nothing is written until
one of the first two is chosen.

## `generate`

Create a project from an existing `scaffold.yml`.

```bash
xscaffold generate
xscaffold generate --config configs/app.yml --destination ../App
xscaffold generate --yes --output json
```

| Flag | Meaning |
|---|---|
| `--config <path>` | The configuration. Defaults to `./scaffold.yml`. |
| `--destination <path>` | Where to create it. Defaults to `./<project.name>`. |
| `--yes`, `-y` | Skip the confirmation. Required where there is no terminal. |
| `--force` | Write into a destination that is not empty. |
| `--validate-build` | Build the generated project before reporting success. |
| `--skip-git` | Do not create a git repository. |
| `--skip-generate` | Do not run the generator. |
| `--output <text\|json>` | How to report the result. |

A run without `--yes` shows a summary and waits, so it needs a terminal.

## `validate`

Check a `scaffold.yml`. Writes nothing.

```bash
xscaffold validate scaffold.yml
xscaffold validate scaffold.yml --output json
```

Reports every problem rather than the first, so five mistakes take one run to
find. Exit code `4` means the configuration cannot be generated; the `issues`
array says why, one entry per problem, each with a code, the field's path, a
message and usually a suggestion. See [configuration.md](configuration.md) for
the codes.

## `plan`

Show what `generate` would create. Writes nothing.

```bash
xscaffold plan --config scaffold.yml
xscaffold plan --config scaffold.yml --files
xscaffold plan --config scaffold.yml --resolved-config
```

| Flag | Meaning |
|---|---|
| `--config <path>` | The configuration. Defaults to `./scaffold.yml`. |
| `--destination <path>` | Where the project would go. |
| `--files` | List every file and command in the plan. |
| `--resolved-config` | Show the configuration with every default and preset value filled in. |
| `--skip-git`, `--skip-generate` | Preview a run with those steps left out. |
| `--output <text\|json>` | How to report the result. |

`plan` shares `generate`'s inputs and its implementation, so a preview cannot
disagree with the run it previews. It reports file paths and byte counts, never
file contents — the plan for a bare project is some forty kilobytes of source,
and nothing a caller does with a preview needs it.

If the destination already holds files a run would replace, the plan lists them
under `overwrites`.

## `doctor`

Check that the tools generation needs are installed.

```bash
xscaffold doctor
xscaffold doctor --config scaffold.yml --output json
```

Separates what generation cannot do without — `git`, `xcodegen`, and CocoaPods
or Bundler when the configuration reads pods — from what only the generated
project needs later: `xcodebuild`, `swiftlint`, `swiftformat`. Only a missing
requirement exits `10`.

Passing `--config` makes the answer specific to one project: CocoaPods is
required exactly when that configuration reads pods.

## `capabilities`

Show what this version can generate. Writes nothing.

```bash
xscaffold capabilities
xscaffold capabilities --output json
```

Lists the variants, presets, platforms, architectures, dependency modes, test
frameworks, schema versions and named features this binary supports. It is the
command to consult instead of guessing, and the one an agent should call first.

## `config example`

Print an editable `scaffold.yml` to start from. Writes nothing.

```bash
xscaffold config example > scaffold.yml
xscaffold config example --preset standard > scaffold.yml
xscaffold config example --variant macos-appkit --preset production > scaffold.yml
xscaffold config example --preset production --dependency-manager cocoapods > scaffold.yml
```

| Flag | Meaning |
|---|---|
| `--variant <name>` | States that variant's platform and interface. |
| `--preset <name>` | States that preset, resolved in full. |
| `--dependency-manager <mode>` | `none`, `spm`, `cocoapods`, `mixed`. |
| `--output <text\|json>` | Text prints the document; JSON carries it as `resolvedConfiguration`. |

The three flags are independent axes, the same ones `new` has. The document is
the configuration resolved in full rather than one `preset:` line, because an
example exists to be read and changed. Its project identity is a placeholder to
replace.

It prints rather than writes, so the shell decides where the file goes and
nothing it does can overwrite anything.

## Shell completions

Homebrew installs completions for zsh, bash and fish. For any other
installation:

```bash
xscaffold --generate-completion-script zsh  > ~/.zsh/completions/_xscaffold
xscaffold --generate-completion-script bash > ~/.bash_completion.d/xscaffold
xscaffold --generate-completion-script fish > ~/.config/fish/completions/xscaffold.fish
```

Subcommands and flags complete, and so do the values worth not having to
remember: `--variant`, `--preset` and `--dependency-manager` offer their real
values, `--config` and `validate` offer `.yml` and `.yaml` files, and
`--destination` offers directories. The lists come out of the binary, so they
are whatever that binary can actually generate.

## Machine-readable output

`--output json` puts one JSON document on stdout and nothing else; anything a
person would read goes to stderr. Failures produce a document too — that is
when a caller needs it most.

```console
$ xscaffold validate scaffold.yml --output json
{"command":"validate","exitCode":0,"issues":[],"ok":true}
```

`ok`, `command` and `exitCode` are always present, and `message` on failure.
`issues`, `plan`, `resolvedConfiguration`, `checks`, `capabilities`,
`destination`, `phase` and `error` appear only when that command has them to
report — an absent key, never `null`.

### What a failure says

```console
$ xscaffold generate --yes --output json | jq '{phase, error}'
{
  "phase": "dependencyInstallation",
  "error": {
    "code": "POD_INSTALL_FAILED",
    "message": "`bundle exec pod install` failed with exit status 1, …",
    "exitCode": 8,
    "command": "bundle exec pod install",
    "recoverySuggestion": "Run the install again with --verbose in the destination …"
  }
}
```

`code`, `message`, `exitCode` and `recoverySuggestion` are always there;
`command` appears when an external command failed and `path` when the failure is
about a file or directory.

`phase` says how far the run got. Everything up to and including `confirmation`
happens before anything is written. See
[ADR-0009](adr/0009-a-failure-reports-the-stage-it-was-in.md).

### Every code

The three frozen strings of a failure, together. `phase` is the stage the code
alone settles; `UNEXPECTED_FAILURE` is what is left when nothing fits, so it
names none.

| `error.code` | `exitCode` | `phase` |
|---|---|---|
| `INVALID_ARGUMENTS` | `2` | `invocation` |
| `CONFIGURATION_UNREADABLE` | `3` | `configuration` |
| `CONFIGURATION_MALFORMED` | `3` | `configuration` |
| `SCHEMA_VERSION_UNSUPPORTED` | `3` | `configuration` |
| `CONFIGURATION_INVALID` | `4` | `validation` |
| `TEMPLATE_CONFLICT` | `5` | `planning` |
| `TEMPLATE_RESOLUTION_FAILED` | `5` | `planning` |
| `OUTPUT_DIRECTORY_NOT_EMPTY` | `6` | `generation` |
| `OUTPUT_DIRECTORY_HAS_PROJECT` | `6` | `generation` |
| `OUTPUT_PATH_NOT_A_DIRECTORY` | `6` | `generation` |
| `OUTPUT_PATH_BLOCKED_BY_DIRECTORY` | `6` | `generation` |
| `UNSAFE_PLANNED_PATH` | `7` | `generation` |
| `XCODEGEN_NOT_INSTALLED` | `10` | `projectGeneration` |
| `COCOAPODS_NOT_INSTALLED` | `10` | `dependencyInstallation` |
| `BUNDLER_NOT_INSTALLED` | `10` | `dependencyInstallation` |
| `EXECUTABLE_NOT_FOUND` | `10` | `generation` |
| `ENVIRONMENT_REQUIREMENT_MISSING` | `10` | `environmentCheck` |
| `XCODEGEN_FAILED` | `8` | `projectGeneration` |
| `POD_INSTALL_FAILED` | `8` | `dependencyInstallation` |
| `COMMAND_FAILED` | `8` | `generation` |
| `WORKSPACE_NOT_GENERATED` | `7` | `dependencyInstallation` |
| `GENERATION_FAILED` | `7` | `generation` |
| `BUILD_VALIDATION_FAILED` | `9` | `buildValidation` |
| `GENERATION_CANCELLED` | `130` | `confirmation` |
| `UNEXPECTED_FAILURE` | `1` | — |

`EXECUTABLE_NOT_FOUND` is the one code that arrives from more than one stage —
which stage was missing its tool depends on which tool — so a failure may carry
a phase other than the one above.

In text mode the same facts arrive on stderr:

```text
Error: OUTPUT_DIRECTORY_NOT_EMPTY: '/tmp/Bookshelf' already exists and is not empty.
Try: Choose an empty destination, or pass --force to write into this one anyway.
```

## Exit codes

```text
0   success                        6   file conflict
1   unexpected failure             7   generation failure
2   invalid CLI arguments          8   external command failure
3   configuration parsing failure  9   build validation failure
4   configuration validation      10   environment requirement missing
5   template resolution failure   130  cancelled (new, generate)
```

Branch on the exit code for *what kind* of failure, and on `error.code` when
that is too coarse: `XCODEGEN_NOT_INSTALLED` and `COCOAPODS_NOT_INSTALLED` are
both `10` and two different things to install. [Every code](#every-code) pairs
each with the number it exits with.

## Where generation may land

Two tiers, and a flag that only moves the first (see
[ADR-0001](adr/0001-scaffold-yml-as-birth-certificate.md) for why the second is
absolute):

| Destination | Result |
|---|---|
| Empty, or does not exist | Written |
| Holds only a `scaffold.yml` | Written — that is what "save now, generate later" leaves |
| Holds anything else | `OUTPUT_DIRECTORY_NOT_EMPTY`, exit `6`. `--force` writes into it |
| Holds an `.xcodeproj`, `.xcworkspace`, `project.yml` or source | `OUTPUT_DIRECTORY_HAS_PROJECT`, exit `6`. No flag changes this |

`--force` moves into a directory; it never empties one. It replaces the paths
the plan names and leaves everything else alone, and `plan` lists exactly those
paths under `overwrites` beforehand.

## `init`

Removed in v0.6. Typing it gets a pointer to `new` and `generate`.
