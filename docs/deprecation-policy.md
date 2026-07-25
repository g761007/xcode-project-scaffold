# Deprecation policy

What counts as a breaking change, how much warning one gets, and what a warning
looks like.

This policy governs the three contracts v0.9 freezes — the `scaffold.yml`
schema, the CLI, and the JSON output. Anything outside them can change in any
release without notice; the list of what is *not* contract is as much a part of
this document as the list of what is.

> **Before 1.0 this policy describes intent, not a promise.** The `0.x` series
> makes no compatibility guarantee, and this document exists so that the
> guarantee 1.0 makes is one the project has already been keeping. Where a 0.x
> release departs from it, the CHANGELOG says so and why.

## What is a breaking change

| Contract | Breaking |
|---|---|
| **Schema** | Removing a field. Narrowing what a field accepts. Changing what a field *means*. Changing a default in a way that changes the generated project. Retiring a `schemaVersion`. |
| **CLI** | Removing a command or a flag. Renaming either. Making an optional argument required. Changing an exit code's number or its meaning. |
| **JSON** | Removing a key, or changing its type. Making a key that was always present conditional. Changing an `exitCode`, `ValidationCode`, `ScaffoldErrorCode` or `ScaffoldPhase` string. |

Adding is not breaking: a new field with a default, a new optional flag, a new
key that appears only when it has something to say, a new enum case in a
position where callers already handle values they do not know.

Two consequences worth stating out loud, because both look like additions:

- **A new validation rule is breaking.** A configuration that generated
  yesterday and is refused today is broken for its owner, whatever the rule's
  merit. `XS0014` (v0.6.1) was exactly this, and shipped as a patch because the
  alternative was generating projects that could not compile. Under this policy
  that is a defensible reason to break the rule, and the reason belongs in the
  CHANGELOG.
- **A new `schemaVersion` is not breaking, and refusing an old one is.** Adding
  version 2 leaves version 1 documents working. Dropping version 1 is the
  removal this policy is about.

## What is not contract

Stating this precisely is what makes the rest of the policy affordable. None of
the following is frozen, and none of it changes with a major version:

- The wording of any message — errors, warnings, help text, prompts. A code is
  contract; the English beside it is not. Callers branch on `error.code` and
  `exitCode`; anything matching on message text is matching on prose.
- The order and phrasing of the interactive `new` questions.
- The contents of the generated project: its sources, its `Makefile`, its
  `README.md`, its lint configuration. These are templates, and improving them
  is the point of the tool. A generated project is a starting point, not a
  dependency — `xscaffold` steps out of the way once it exists
  ([ADR-0001](adr/0001-scaffold-yml-as-birth-certificate.md)).
- Anything printed under `--output text`. The text form is for people; the
  contract is the JSON.
- Internal Swift API. The package is an executable, not a library.

## Notice period

Measured in **minor versions, not in time** — this project's release cadence is
irregular, and a date-based promise would either be meaningless during a busy
month or block a release during a quiet one.

| Stage | Duration | What happens |
|---|---|---|
| **Announced** | at least one minor version | The CHANGELOG names it, the documentation marks it, and using it prints a warning to stderr naming the replacement. Behaviour does not change. |
| **Removed** | the following minor version at the earliest | The thing is gone. Where the name would otherwise produce an unknown-command shrug, a tombstone stays behind pointing at the replacement. |

After 1.0, **removal requires a major version**, and the announcement period
still applies within the major series that precedes it.

A warning goes to stderr, never to stdout — under `--output json` stdout is one
document and nothing else (§11.3), and a deprecation notice is not part of it.

## How a deprecation is written down

1. A `### Deprecated` section in the CHANGELOG, naming the replacement.
2. A note in the document that describes the thing, in the same PR.
3. A runtime warning naming the replacement, where there is a moment to print
   one.
4. Where the surface is machine-readable, `capabilities` stops advertising it
   only when it is removed — not while it still works.

## The two removals that have already happened

Both predate this policy. They are here because a policy that cannot judge the
project's own history is not one anybody will apply to its future.

### `init`, removed in v0.6

Announced in v0.4 with a stderr warning on every run naming both replacements,
removed in v0.6, and a hidden tombstone command still answers `xscaffold init`
with a pointer rather than an unknown-command error
([ADR-0007](adr/0007-init-retires-preset-becomes-variant.md)).

**Verdict: this is what the policy asks for**, and would be allowed after 1.0
as part of a major release. Two minor versions of warning exceeded the minimum;
the tombstone is the part worth copying, because the cost of keeping one is a
few lines and the cost of not having one is a user reading "unknown command"
about something the documentation mentioned last month.

### `--preset` changed meaning between v0.4 and v0.7

Between v0.4 and v0.6 `--preset` named four platform combinations. v0.4 moved
those to `--variant` and left `--preset` erroring with a pointer; v0.7 gave the
flag back with a new meaning — a project's scale.

**Verdict: this would not be allowed after 1.0.** Changing what a flag means,
even with an intervening period where it errors, is the one change a caller
cannot detect: a script passing `--preset ios-uikit` gets a clear error, but a
person who remembers the old meaning gets a different project than they expect.
The reason it was acceptable here is written in ADR-0007 and does not survive
1.0: the tool had not been promoted, so the change cost a handful of early
users one edit each. After 1.0 the same move needs a new flag name.

## Changing this policy

A change to what is frozen is itself announced the same way, and the freeze
documents ([schema](configuration.md), [CLI](cli-reference.md),
[JSON](cli-reference.md#machine-readable-output)) name the contract tests that
enforce it. Changing a contract means changing a test that was deliberately
written to fail on that change — which is the point.

See also [compatibility-policy.md](compatibility-policy.md) for which macOS,
Xcode and toolchain versions are supported.
