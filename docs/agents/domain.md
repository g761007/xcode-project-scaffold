# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

**Layout: single-context.** `CONTEXT.md` and `docs/adr/` live at the repo root.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root — the project glossary.
- **`docs/adr/`** — read ADRs that touch the area you're about to work in.

If either of these doesn't exist, **proceed silently**. Don't flag their absence; don't suggest creating them upfront. The `/domain-modeling` skill (reached via `/grill-with-docs` and `/improve-codebase-architecture`) creates them lazily when terms or decisions actually get resolved.

## File structure

```
/
├── CONTEXT.md
├── docs/adr/
│   ├── 0001-scaffold-yml-as-birth-certificate.md
│   └── 0002-build-project-yml-from-swift-types.md
└── Sources/
```

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids.

The glossary is opinionated on purpose. `Capability` means Xcode's native capabilities, never a technology choice; `Provider` means the implementer of a technology choice; `Feature` means a module in the user's app. Getting these wrong produces documentation and issue titles that read plausibly but mean the wrong thing.

If the concept you need isn't in the glossary yet, that's a signal — either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0001 (scaffold.yml as a birth certificate) — but worth reopening because…_
