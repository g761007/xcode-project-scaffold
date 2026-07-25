# 8. Presets merge as YAML nodes, before decoding

Date: 2026-07-25

## Status

Accepted

## Context

A preset is a named set of defaults (§17). The spec fixes the resolution order:
**Preset Defaults → User Overrides → Normalization → Validation**.

That order needs a distinction the decoder deliberately destroys. Every optional
field in `scaffold.yml` takes its default the moment it decodes —
`quality.swiftlint` is `true` whether the user wrote `true` or wrote nothing at
all. By the time a `ProjectConfiguration` exists, "stated" and "unstated" are
the same value, so a preset cannot know which of its defaults it is allowed to
supply. `minimal` wants no linters; a user who wrote nothing would still get
them, because the decoder already said `true`.

Two ways to keep the distinction:

1. **A full-optional mirror of the schema.** Decode into a type where every
   field is `Optional`, merge the preset into the empty slots, then run the
   existing default-applying initialiser. `PartialProjectConfiguration` is this
   shape already, but only for the seven fields `new` asks about.
2. **Merge before decoding.** The distinction is already perfectly represented
   in the document itself: a stated field is a key that is present. Merge the
   preset's document with the user's, user winning, and hand the result to the
   decoder that exists.

## Decision

Merge as `Yams.Node` trees, before decoding.

Presets are authored as YAML literals. `Yams.compose` turns both documents into
nodes, a recursive merge overlays the user's onto the preset's — a mapping merges
key by key, anything else is replaced outright — and `YAMLDecoder.decode(_:from:)`
takes the merged node. Normalization and validation then run exactly as they do
for a document with no preset.

## Consequences

The decoder stays the single place defaults are applied, and presets add no
second copy of the schema to keep in step with it. Option 1 would have meant a
mirror type with an optional for every field, updated in lockstep forever — the
kind of duplication that is correct on the day it is written and wrong six
months later.

Merging nodes rather than text also keeps scalars exactly as written. A
round-trip through `load` and `dump` would read `deploymentTarget: 18.10` as the
float `18.1` — a different iOS release — which is the same hazard
`XcodeGenSpecEncoder` already quotes against.

The cost is that a preset is YAML rather than Swift, so a typo in one is caught
by its tests rather than by the compiler. Each preset is therefore asserted
through the decoder, which is where such a typo shows up as a wrong resolved
value.

A list is replaced, not merged: `environments: []` under a preset that supplies
three means none, because stating a list is stating all of it. Anything else
would leave no way to ask for fewer.
