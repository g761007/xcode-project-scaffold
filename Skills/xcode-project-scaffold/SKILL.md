---
name: xcode-project-scaffold
description: Create a new Xcode project from a description in words, by writing a scaffold.yml and calling the xscaffold CLI. Use when someone asks for a new iOS app project, an Xcode project skeleton, or a project generated from an existing scaffold.yml.
---

# Creating an Xcode project with xscaffold

`xscaffold` turns a declarative `scaffold.yml` into a real project — sources,
`project.yml`, lint and format configuration, a `Makefile`, and a git repository
with one commit — and guarantees the same configuration produces the same
project.

Call the CLI directly. Every command takes `--output json` and exits with a code
that says what went wrong; a wrapper script would only hide both. If `xscaffold`
is not on the PATH, say so and stop — it is installed with `make install` from
its repository.

## The workflow

1. **Check the machine.** `xscaffold doctor --output json`. Exit code `10` means
   something a default `init` cannot proceed without is missing. Stop and name
   it, rather than generating a project that fails half way through.
2. **Write a `scaffold.yml`** from what the user asked for. Fields, defaults and
   allowed values are in `references/configuration-schema.md`. Put it outside
   the destination: `init` writes its own copy into the project.
3. **Validate it.** `xscaffold validate <path> --output json`. Fix what it
   reports and validate again. Never generate from a configuration that has not
   come back clean.
4. **Preview it.** `xscaffold plan --config <path> --output json`, and show the
   user what will be created before creating it.
5. **Create it.** `xscaffold init --config <path> --output json`. Report the
   `destination` it gives back.

`--destination <path>` chooses where the project goes; without it, `init`
creates `./<project.name>`.

For a request with nothing in it beyond "an iOS app in SwiftUI", steps 2 to 4
can be one preset instead — `xscaffold init MyApp --preset ios-swiftui`, or
`--preset ios-uikit`. A preset derives the bundle identifier as
`com.example.myapp`, so it suits someone who has not said what theirs is.
`init` validates whatever it is given either way, and exits `4` if that fails;
running `validate` first is how you get the issues before anything is written.

## Reading the output

All four commands answer with one JSON document on stdout, in the same envelope,
whether they succeeded or failed:

```json
{"command":"validate","exitCode":0,"issues":[],"ok":true}
```

`ok`, `command` and `exitCode` are always present, and `message` on failure.
`issues`, `plan`, `checks` and `destination` appear when that command has them to
report — an absent key, never `null`. Anything a person would read goes to
stderr, so stdout always parses.

Branch on `exitCode`, not on the message:

```text
0   success                        6   file conflict
1   unexpected failure             7   generation failure
2   invalid CLI arguments          8   external command failure
3   configuration parsing failure  9   build validation failure
4   configuration validation       10  environment requirement missing
5   template resolution failure
```

`plan` reports file paths and byte counts, not file contents. To show someone
what they are about to get, that is the list to show.

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
- **The `.xcodeproj` is XcodeGen's.** `init` runs it. Never run it yourself, and
  never hand-write a project file.
- **A non-empty destination is the user's.** Exit code `6` says the directory
  already has something in it. `--force` overrides that; asking first is the
  point.

## After the project exists

`project.yml` becomes the project's source of truth and `xscaffold` steps out of
the way. The `scaffold.yml` inside the project is a record of how it was created
— editing it changes nothing, and there is no regenerate, upgrade or migrate
command. Someone who wants a different project creates one.
