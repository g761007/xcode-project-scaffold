# Pre-freeze contract review

Carried out for v0.9 (#137), over the three contracts [contracts.md](contracts.md)
freezes: the `scaffold.yml` schema, the CLI, and the JSON output.

Each contract has its own freeze ticket, and each of those asks the same
question: *is this pinned by something that fails when it changes?* This review
asks a different one, and the only one that has a deadline —

> **Is the contract itself right?**

Freezing is a one-way door. After 1.0, renaming a field, dropping a key or
changing what a flag means costs a major version. Anything wrong that is cheap
to fix now is expensive forever afterwards, so the question is worth asking once
deliberately rather than discovering the answer from an issue in 2027.

Every conclusion is below: what changed, what did not, and why. "No change" is a
result, not a gap — several of these are things that look wrong and are not.

## Changed

### 1. `capabilities.schemaVersions` reported the version it writes

It was built from `ConfigurationDefaults.schemaVersion` — the version stamped
into a generated document — while the check that refuses a document reads
`ConfigurationDefaults.supportedSchemaVersions`. Two constants, one statement.

Nothing caught it, and nothing would have: both are `1` today, so the test
asserting the two agree passed while comparing a value against itself by
coincidence. The first release that reads two schema versions and writes one
would have had `capabilities` advertise a version and the coder accept a
different set — and the recovery suggestion for `SCHEMA_VERSION_UNSUPPORTED`
sends the reader to `capabilities` to find out which versions are accepted.

**Changed** to read `supportedSchemaVersions`. The existing test now holds for
the reason it states.

### 2. `capabilities.features` had no rule behind it

Seven of the eight lists in `capabilities` are sourced from the type that
enforces them, so what is advertised and what is accepted cannot disagree.
`features` was a hand-written literal, and it had already drifted from §19,
which specifies it: one name renamed (`environments` → `environment-values`),
two dropped, one added. None of that was recorded anywhere, and no test could
have noticed, because there was nothing to compare against.

The concrete failure it was heading for: `AppExtensionKind` exists so that a
third App Extension is one entry in a table rather than a copy of the machinery
around it — but `features` was not in that table, so the third extension would
have generated correctly and been advertised as unsupported. An agent reads
`capabilities` *instead of guessing*; that is the one way to make it guess.

**Changed:**

- `environment-values` is back to §19's `environments`, which is also the name
  of the section that turns it on. This is a breaking change to the JSON
  output, and it is why the review has a deadline.
- The two extension names come from `AppExtensionKind`, and `github-actions` is
  `CIProvider`'s own raw value, so three of the seven are now derived.
- The rule is written down: a feature is an optional capability, named after
  the section that turns it on.
- §19's `spm-dependencies` and `cocoapods` stay out, deliberately —
  `dependencyManagementModes` already answers that question, and two lists that
  must agree eventually do not. `secrets` stays in; §19 simply missed it.
- `CapabilitiesTests` pins the list, the derivation, and the kebab-case
  spelling, so the next entry cannot arrive as `notificationService`.

### 3. `message` could disagree with `error.message`

The document said `message` is always the same sentence as `error.message`.
Nothing made that true: the success initialiser took a `message` parameter, so
a `message` with no `error` behind it was constructible and would have
type-checked.

**Changed** structurally rather than by assertion: the success form no longer
takes a message, the property is `private(set)`, and the failure form takes it
from the error. The same now goes for `exitCode`, which the envelope also
repeats.

Not removed — see below.

## Not changed

### 4. `message` duplicating `error.message`, and `exitCode` duplicating `error.exitCode`

The ticket names 1.0 as the last chance to drop the top-level `message`. The
answer is to keep both, and the reason is the same for both keys: the error
object has to be worth detaching from its envelope. A caller that logs, queues
or forwards a `ScaffoldError` on its own needs it to carry its own exit status
and its own sentence, and a caller written against v0.2 — when `--output json`
first shipped and `error` did not exist for another six releases — needs the
top-level keys.

Removing the older and more widely read of two keys carrying the same value
costs those callers and buys tidiness. What made the duplication worth
questioning was that it could drift; item 3 removed that. Two keys that cannot
disagree are a convenience, not a hazard.

### 5. The wording of any message, including `error.message`

Not contract, and now said so in three places: the deprecation policy, this
review, and `contracts.md`. Codes are what a caller branches on; that is what
`ScaffoldErrorCode` and `ValidationCode` are for, and both are frozen.

The question was worth asking because the sentence appears twice, which made it
*look* load-bearing. It is prose in both places.

### 6. All ten `ScaffoldPhase` values are reachable

A phase nothing can report would be a string in the contract that no run
produces — a caller writing a branch that never fires, frozen in.

Two things had to hold, and only one of them is now a test.

`ErrorContractTests` asserts the covering in both directions: every code has
the phase the table gives it, and every phase is named by at least one code.
That is the half a test can state, and it is the half that would break first —
a code retired without noticing that it was the only one reporting its stage.

The other half is that every *code* has a failure path that constructs it, and
that was checked by hand across all twenty-five: each is built somewhere
outside its own enum. It is not pinned. Pinning it would mean either provoking
twenty-five real failures or reading Swift source from a test, and neither is
worth what it costs — the codes were audited the same way when they were
chosen in v0.8, and six that nothing could emit were dropped then.

### 7. `validate <path>` is positional and required; `generate --config` is a flag with a default

Three commands read a `scaffold.yml`, and one of them asks for it differently.
`xscaffold plan` works in a directory that has one; `xscaffold validate <path>`
insists on being told which file, in a directory where the answer is obvious.

**Deliberately left alone**, because it is the rare wart that costs nothing to
leave: making a required argument optional breaks no existing invocation, so
this can be fixed in any 1.x release. The freeze does not close this door.

### 8. `new --open` has no counterpart on `generate`

Same reasoning: adding a flag is additive, and the deprecation policy treats it
as such. `--open` arrived with the interactive command because that is where a
person is sitting; if `generate` wants it later, it can have it in a minor
release.

### 9. `testing.unit` is a string, `testing.ui` is an object

An asymmetry a reader notices: `unit: none` turns unit tests off in one word,
while UI tests need `ui.enabled: false`. Making them symmetric means either
giving `unit` an object it has no second option to hold, or taking
`launchPerformanceTest` away from `ui`.

**No change.** The shapes differ because the things differ, both spellings are
documented, and a schema is not improved by making a field carry a wrapper for
symmetry's sake.

### 10. `language.languageMode` stutters

`language: { primary: swift, languageMode: '6' }` reads as language.language.
`mode` would be shorter.

**No change.** "Swift language mode" is the term the Swift project uses, and a
reader searching the field name finds the right documentation. Four characters
is not worth being the only field in the schema that renames an upstream
concept.

### 11. `ok` is derivable from `exitCode`

Kept. It is derived — no caller can produce a document claiming success while
exiting 4 — and a caller that only wants pass/fail should not need the exit
code table to get it.

## What this review did not cover

- Whether each *value* in a frozen vocabulary is the right value. That is what
  the `XS0xxx` capability-boundary codes are for, and moving a boundary is
  explicitly not a breaking change.
- The generated project's own files. The deprecation policy puts them outside
  all three contracts on purpose: they are a starting point, not an interface.
- Signing and notarization (#136), which need credentials this review had no
  access to.
