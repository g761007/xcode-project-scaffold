# Driving xscaffold from an agent

The machine-readable path is a first-class use case, not an afterthought. Every
command but the interactive `new` takes `--output json`, puts exactly one
document on stdout, and exits with a code that says what kind of failure it was.

A ready-made Skill is in
[`Skills/xcode-project-scaffold/`](../Skills/xcode-project-scaffold/) —
`SKILL.md` is the workflow, and `references/configuration-schema.md` is the
field reference to consult while writing a `scaffold.yml`. This page is the same
contract for anything that is not that Skill.

## The workflow

```bash
xscaffold capabilities --output json          # what can this binary do?
xscaffold doctor --output json                # what is installed?
# write scaffold.yml
xscaffold validate scaffold.yml --output json
xscaffold plan --config scaffold.yml --output json
xscaffold generate --config scaffold.yml --yes --output json
```

Each step exists to fail before the expensive one:

1. **`capabilities`** lists the variants, presets, platforms, architectures,
   dependency modes, test frameworks and schema versions this binary supports.
   Consult it rather than guessing options — it is the only source that cannot
   be out of date with the binary in front of you.
2. **`doctor`** answers what is installed. Exit `10` means generation cannot
   proceed; name the missing tool and stop, rather than generating a project
   that fails half way through. Pass `--config` once the file exists, because
   CocoaPods is required exactly when the configuration reads pods.
3. **Write the file.** State what was decided and leave everything else out —
   a [preset](presets.md) fills the rest. `config example` prints a resolved
   document to read first.
4. **`validate`** before anything else. A configuration that has not come back
   clean is one you have not checked.
5. **`plan`** and show the user what will be created before creating it.
   `--resolved-config` adds the configuration with every default and preset
   value filled in.
6. **`generate --yes`**. `--yes` is required without a terminal; without it the
   command asks for confirmation and refuses when there is nobody to ask.

For a request with nothing in it beyond "an iOS app in SwiftUI", steps 3 to 6
collapse to one line:

```bash
xscaffold new MyApp --variant ios-swiftui --preset standard --yes
```

Take that path only when there is genuinely nothing else to state. Packages,
environments, extensions and CI belong in a `scaffold.yml`, where a human can
read and review them.

## The envelope

```json
{"command":"validate","exitCode":0,"issues":[],"ok":true}
```

`ok`, `command` and `exitCode` are always present, and `message` on failure.
`issues`, `plan`, `resolvedConfiguration`, `checks`, `capabilities`,
`destination`, `phase` and `error` appear only when that command has them to
report — an absent key, never `null`. Anything a person would read goes to
stderr, so stdout always parses.

`plan` carries file paths and byte counts, never file contents.

## Branching on failure

Branch on `exitCode` for the kind of failure, and on `error.code` when that is
too coarse — `XCODEGEN_NOT_INSTALLED` and `COCOAPODS_NOT_INSTALLED` are both
exit `10` and two different things to install.

`phase` says how far the run got, which decides what to say next:

| Phase | Anything on disk? |
|---|---|
| `invocation`, `configuration`, `validation`, `planning`, `confirmation` | No |
| `generation`, `projectGeneration`, `dependencyInstallation` | Possibly; the message says so when files were left behind |
| `buildValidation` | Yes — the project generated and only the build check failed |
| `environmentCheck` | No; `doctor` reporting a missing tool |

Pass `error.recoverySuggestion` on rather than inventing one: it is written
against the code and does not guess at what the user was doing.

The full table of codes and phases is in
[cli-reference.md](cli-reference.md#machine-readable-output).

## Acting on what validate reports

Each issue carries a `code`, the `path` of the field at fault, a `message` and
usually a `suggestion`. The code's family decides what to do with it:

- **`XS0xxx` — valid, but not supported in this version.** The suggestion names
  what this version does support. Switching to it changes what the user asked
  for, so say what changed rather than doing it silently.
- **`XS1xxx` — invalid in every version.** A bundle identifier that is not
  reverse-DNS is a mistake, not a preference. Fix it and move on.

Apply a suggestion unprompted when the fix is unambiguous and does not change
what was asked for. Ask when it does — dropping to `minimal` from an
architecture the user named is a different project.

## What not to do

- **Do not run XcodeGen yourself, and never hand-write a project file.**
  `generate` runs it, and the `.xcodeproj` is derived from `project.yml`.
- **Do not skip `validate`.** Every rule about what combines with what lives
  there. Reasoning about it instead is how an agent generates a project that
  cannot compile.
- **Do not pass `--force` to get past a non-empty destination** without asking.
  Exit `6` is a question for the user, and `plan` has already listed exactly
  which files would be replaced.
- **Do not edit a generated `scaffold.yml` expecting anything to change.** It is
  a record of how the project was created. `project.yml` is the project's source
  of truth from then on, and there is no regenerate command.
