---
name: xcode-project-scaffold
description: Create a new Xcode project from a description in words, by writing a scaffold.yml and calling the xscaffold CLI. Use when someone asks for a new iOS app project, an Xcode project skeleton, or a project generated from an existing scaffold.yml.
---

# Creating an Xcode project with xscaffold

`xscaffold` turns a declarative `scaffold.yml` into a real project — sources,
`project.yml`, lint and format configuration, a `Makefile`, and a git repository
with one commit — and guarantees the same configuration produces the same
project.

Call the CLI directly. The commands this skill uses — `capabilities`,
`config example`, `validate`, `plan`, `generate` and `doctor` — take
`--output json` and exit with a code that says what went wrong; a wrapper
script would only hide both. If `xscaffold` is not on the PATH, say so and
stop — it is installed with `brew install g761007/tap/xscaffold`, or
`make install` from its repository.

There is also an interactive `xscaffold new`, which asks a person questions at a
terminal. It is not for this skill: an agent has the answers already, so it
writes a `scaffold.yml` and takes the declarative path below.

## The two axes

Two independent choices run through every command here, and confusing them is
the most common way to ask for the wrong project:

- **Variant** — the platform and the interface: `ios-uikit`, `ios-swiftui`,
  `macos-swiftui`, `macos-appkit`. In `scaffold.yml` it is two fields,
  `product.platform` and `interface.primary`; on the command line it is one
  name.
- **Preset** — how much project: `minimal`, `standard`, `production`. A scale,
  not a platform. It supplies only what the document leaves unstated, so
  anything written wins over it, including an explicit `false` against a
  preset's `true`.

They compose freely. `--preset` named platform combinations before v0.4 and no
longer does; a variant name given to it is refused with a pointer to
`--variant`.

## The workflow

1. **Ask what this version can do.** `xscaffold capabilities --output json`
   lists the variants, presets, architectures, dependency modes, test
   frameworks and features this binary actually generates — consult it instead
   of guessing options.
2. **Check the machine.** `xscaffold doctor --output json` (pass
   `--config <path>` once the scaffold.yml exists — CocoaPods is required
   exactly when the configuration reads pods). Exit code `10` means something
   generation cannot proceed without is missing. Stop and name it, rather than
   generating a project that fails half way through.
3. **Write a `scaffold.yml`** from what the user asked for. Fields, defaults and
   allowed values are in `references/configuration-schema.md`. Put it outside
   the destination: `generate` writes its own copy into the project.

   State only what was decided. Everything else has a default, and a preset
   fills the rest — `preset: standard` with four stated fields is a better
   document than forty fields copied out of a reference. To see what a preset
   resolves to before choosing one:
   `xscaffold config example --preset production --variant ios-swiftui`.
4. **Validate it.** `xscaffold validate <path> --output json`. Fix what it
   reports and validate again. Never generate from a configuration that has not
   come back clean.
5. **Preview it.** `xscaffold plan --config <path> --output json`, and show the
   user what will be created before creating it. Adding `--resolved-config`
   puts the configuration with every default and preset value filled in beside
   the file list — that is what to show when the user asks what a preset
   actually gave them.
6. **Create it.** `xscaffold generate --config <path> --yes --output json`.
   `--yes` is required for a non-interactive run — without it, `generate` asks
   at a terminal, and refuses when there is none. Report the `destination` it
   gives back.

`--destination <path>` chooses where the project goes; without it, `generate`
creates `./<project.name>`.

For a request with nothing in it beyond "an iOS app in SwiftUI", steps 3 to 5
can be one line instead:

```bash
xscaffold new MyApp --variant ios-swiftui --preset standard --yes
```

`--yes` with `--variant` skips the questions as well as the confirmation, so
this needs no terminal. It derives the bundle identifier as `com.example.myapp`,
which suits someone who has not said what theirs is. Take this path only when
there is nothing else to state: anything beyond the two axes — packages,
environments, extensions, CI — belongs in a `scaffold.yml`, where it can be read
and reviewed.

The old `init` was removed in v0.6; typing it gets a pointer to the two commands
above.

## Reading the output

These commands answer with one JSON document on stdout, in the same
envelope, whether they succeeded or failed:

```json
{"command":"validate","exitCode":0,"issues":[],"ok":true}
```

`ok`, `command` and `exitCode` are always present, and `message` on failure.
`issues`, `plan`, `resolvedConfiguration`, `capabilities`, `checks` and
`destination` appear when that command has them to report — an absent key,
never `null`. Anything a person would read goes to stderr, so stdout always
parses.

Branch on `exitCode`, not on the message:

```text
0   success                        6   file conflict
1   unexpected failure             7   generation failure
2   invalid CLI arguments          8   external command failure
3   configuration parsing failure  9   build validation failure
4   configuration validation       10  environment requirement missing
5   template resolution failure    130 cancelled
```

`plan` reports file paths and byte counts, not file contents. To show someone
what they are about to get, that is the list to show.

## Reading a failure

A failure carries `error` and `phase` beside the envelope's `exitCode`:

```json
{
  "ok": false,
  "exitCode": 8,
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

`error.code` is the name to branch on when the exit code is too coarse — it
separates `XCODEGEN_NOT_INSTALLED` from `COCOAPODS_NOT_INSTALLED`, which are
both exit code `10` and two different things to tell the user to install.
`command` appears when an external command failed and `path` when the failure
is about a file or directory.

`phase` says how far the run got, which decides what to say next:

| Phase | Anything on disk? |
|---|---|
| `invocation`, `configuration`, `validation`, `planning`, `confirmation` | No. Nothing was written; fix and re-run. |
| `generation`, `projectGeneration`, `dependencyInstallation` | Possibly. The message says so when files were left behind. |
| `buildValidation` | Yes — the project generated, and only the build check failed. |
| `environmentCheck` | No; this is `doctor` reporting a missing tool. |

Pass `error.recoverySuggestion` on rather than inventing one: it is written
against the code and does not guess at what the user was doing.

## Fixing what validate reports

Each issue carries a `code`, the `path` of the field at fault, a `message`, and
usually a `suggestion`. The code's family decides what to do with it:

- **`XS0xxx` — valid, but not supported in this version.** The suggestion names
  what this version does support. Switching to it changes what the user gets, so
  say what changed rather than doing it silently.
- **`XS1xxx` — invalid in every version.** A bundle identifier that is not
  reverse-DNS, or a lifecycle that contradicts the interface, is a mistake and
  not a preference. Fix it and move on.

Apply a suggestion unprompted when the fix is unambiguous and does not change
what was asked for — a malformed bundle identifier, a deployment target below
the floor. Ask when it does: dropping to `minimal` from an architecture the user
named, or leaving a platform this version cannot build.

Every rule in this version reports `error`. The envelope also carries
`severity: "warning"`, but nothing emits one yet, so a clean `validate` means
`issues` is empty.

## What this skill does not decide

- **Compatibility is `validate`'s.** It owns every rule about what combines with
  what. A configuration you believe is fine and have not run through it is a
  configuration you have not checked.
- **The `.xcodeproj` is XcodeGen's.** `generate` runs it. Never run it yourself, and
  never hand-write a project file.
- **A non-empty destination is the user's.** Exit code `6` says the directory
  already has something in it. `--force` overrides that; asking first is the
  point.

## After the project exists

`project.yml` becomes the project's source of truth and `xscaffold` steps out of
the way. The `scaffold.yml` inside the project is a record of how it was created
— editing it changes nothing, and there is no regenerate, upgrade or migrate
command. Someone who wants a different project creates one.
