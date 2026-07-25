# 9. A failure reports the stage it was in, not the state it ended in

Date: 2026-07-25

## Status

Accepted

## Context

The error contract (§23) requires every failure to carry a **Phase**, and gives
one example value: `dependencyInstallation`.

§7.1 also defines a `ScaffoldPhase`, and says of it: "ScaffoldPhase 是進度回報與
錯誤契約(§23)的輸出詞彙". Its cases are `draft`, `normalized`, `validated`,
`planned`, `confirmed`, `generating`, `generated`, `failed`, `cancelled`.

The two do not agree, and only one of them can be the type that ships.

§7.1's list is a state machine for the value an interactive session carries: a
draft becomes normalized, becomes validated, becomes a plan. Read as the answer
to "where did this fail?", it collapses — `failed` is the state every failure
ends in, and reporting it says nothing a caller did not already know from
`ok: false`. It also cannot distinguish the two failures that behave most
differently: a plan that could not be written and a `pod install` that exited 1
are both `generating`, though only one of them leaves a project on disk.

## Decision

`ScaffoldPhase` names the **stage of work that was under way**, in §23's
vocabulary rather than §7.1's:

```
invocation  configuration  validation  planning  confirmation
generation  projectGeneration  dependencyInstallation
buildValidation  environmentCheck
```

Each case earns its place by changing what the reader does next. The split
before and after `generation` answers "is anything on disk?"; the split between
`projectGeneration` and `dependencyInstallation` answers "is this XcodeGen or
CocoaPods?", which is two different tools to go and run by hand.

The phase is derived from the error code wherever the code settles it
(`ScaffoldErrorCode.phase`), and passed explicitly only where one code arrives
from more than one stage — `EXECUTABLE_NOT_FOUND` is `buildValidation` for
`xcodebuild` and `generation` for `git`.

`UNEXPECTED_FAILURE` has no phase. It is what is left when nothing else fits,
and can arrive from anywhere; a phase for it would be a guess printed as a fact.

## Consequences

§7.1's list is not implemented as a type. Nothing needs it: the states it names
are already represented by which type a value has — `ProjectConfiguration`,
`ValidatedConfiguration`, `GenerationPlan` — which is the distinction §7.1 makes
itself ("不是每個 case 都需要對應一個型別").

Progress reporting, if it arrives, will want the same vocabulary as failure
reporting, and gets it: "generating files" and "failed while generating files"
name the same stage.

The cost is that a reader following the roadmap finds a `ScaffoldPhase` in §7.1
that does not exist in the source. This ADR is the answer to that; the roadmap
is a plan, and this is the record of where the plan was overtaken.
