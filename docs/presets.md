# Presets

A preset answers one question: **how much project**. It is a scale, not a
platform — see [templates.md](templates.md) for the other axis.

```bash
xscaffold new Bookshelf --variant ios-swiftui --preset standard --yes
```

```yaml
preset: standard
project:
  name: Bookshelf
  bundleIdentifier: com.example.bookshelf
interface:
  primary: swiftui
```

Both do the same thing. The flag routes through the document, so `--preset
standard` and a file saying `preset: standard` resolve through one mechanism
rather than two that can disagree.

## What each one brings

| | `minimal` | `standard` | `production` |
|---|---|---|---|
| Architecture | `minimal` | `mvvm`, with its example | `mvvm`, with its example |
| Dependencies | none | SPM | SPM |
| Unit tests | Swift Testing | Swift Testing | Swift Testing |
| UI tests | — | — | ✅ |
| SwiftLint / SwiftFormat | — | ✅ | ✅ |
| Environments | — | development, production | development, staging, production, with values |
| `.xcconfig` values | — | — | ✅ |
| Secrets example | — | — | ✅ |
| Localization | — | — | ✅ |
| GitHub Actions | — | — | build, test, lint |

`minimal` is the bare skeleton: an app that launches, a test target that
compiles, and no opinions. It deliberately has no linters — a project this small
is usually a scratch project or a reproduction case.

`production` additionally pins CocoaPods and runs it through Bundler **when the
project reads pods**. That one is applied in normalization rather than as a
plain default, because whether it applies depends on a
`dependencyManagement.mode` you may have overridden.

## What a preset does not decide

A preset never states the project's identity, its platform or its interface. It
cannot contradict a variant, and the two combine freely:

```bash
xscaffold new Ledger --variant macos-appkit --preset production --yes
```

## Resolution order

Fixed, and worth knowing exactly:

```text
preset defaults  →  your overrides  →  normalization  →  validation
```

The preset supplies only what the document **leaves unstated**. Anything
written wins — including an explicit `false` against a preset's `true`:

```yaml
preset: standard
quality:
  swiftlint: false      # wins; the preset does not put it back
```

That distinction is only visible in the document, which is why presets merge as
YAML nodes before decoding rather than as values afterwards: once the decoder
has applied its defaults, "stated" and "unstated" are the same value. The
reasoning is in [ADR-0008](adr/0008-presets-merge-as-yaml-nodes.md).

Merging follows two rules:

- **A section merges key by key.** Stating one field of `quality` keeps the
  preset's other fields.
- **A list replaces.** `environments: []` under a preset that supplies three
  means *none* — stating a list is stating all of it, and anything else would
  leave no way to ask for fewer.

## Seeing what you would get

```bash
xscaffold config example --preset production --variant ios-swiftui
xscaffold plan --config scaffold.yml --resolved-config
```

The first prints the preset resolved in full, as an editable starting point.
The second answers the same question about a file you already have, including
what your own overrides changed.

The generated project's own `scaffold.yml` records every value the preset
supplied *and* keeps the `preset:` line saying where they came from, so the file
is readable on its own and reading it back resolves to itself.

## Choosing one

- Reaching for a scratch project or a bug reproduction — `minimal`.
- Starting something you intend to keep — `standard`.
- Starting something that ships, with more than one environment and a CI
  pipeline — `production`, then delete what you do not want. Every field it
  supplies is one you can state differently.

Naming no preset is also an answer: the schema's own defaults, which is where
someone writing this file by hand starts anyway.
