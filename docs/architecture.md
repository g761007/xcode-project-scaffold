# Architecture patterns

`architecture.pattern` is `minimal`, `mvvm` or `mvvm-c`. It decides the shape of
the generated sources — and, unless told otherwise, whether a worked example
comes with them.

```yaml
architecture:
  pattern: mvvm
  includeExample: true      # optional; follows the pattern when left out
```

## The three patterns

### `minimal`

One screen, no layers. An app that launches and a test that compiles, and
nothing between them. It is the default, and it will never carry an example —
`includeExample: true` on it is `XS1201`, a permanent error rather than a "not
yet".

Reach for it when the project is a scratch project, a reproduction case, or
something whose architecture you intend to decide yourself on day two.

### `mvvm`

A view model between the view and its state. Available on all four
[variants](templates.md).

With the example, the generated sources are a greeting screen written the
pattern's way:

```text
App/GreetingViewModel.swift      the state, and the one operation on it
App/ContentView.swift            (SwiftUI) the view, observing the model
App/RootViewController.swift     (UIKit / AppKit) the same, in a controller
Tests/GreetingViewModelTests.swift
```

The view model is deliberately the only thing under test. That is the point of
the pattern and the point of the example: the logic is somewhere a test can
reach without a running app.

How the view observes it differs by interface, and the difference matters:

- **SwiftUI** uses `@Observable`, which arrived in iOS 17 and macOS 14. A
  project below that floor with the SwiftUI example is refused as `XS0014`
  before anything is written — it would generate and then fail to compile.
  Switching the example off, or raising `product.deploymentTarget`, both work.
- **UIKit and AppKit** observe through a closure, which has no floor beyond the
  project's own.

### `mvvm-c`

MVVM with a coordinator owning navigation. **UIKit only** — on SwiftUI (a
router over `NavigationStack`) and on AppKit (a window-driven coordinator) an
analogue exists but is not built yet, so asking for it there is `XS0009`: "not
in this version" rather than "never".

The example is a two-screen flow, which is the smallest thing that shows why a
coordinator exists at all:

```text
App/AppCoordinator.swift             owns the navigation controller
App/ItemListViewController.swift     list → detail, without knowing about detail
App/ItemListViewModel.swift
App/ItemDetailViewController.swift
App/ItemDetailViewModel.swift
App/SceneDelegate.swift              hands the window to the coordinator
Tests/ItemListViewModelTests.swift
Tests/ItemDetailViewModelTests.swift
```

Neither view controller pushes the other. The list tells its coordinator that an
item was selected, and the coordinator decides what that means — which is the
whole difference from `mvvm`, and impossible to see in a one-screen example.

## `includeExample`

| Value | Result |
|---|---|
| unstated | Follows the pattern: `mvvm` and `mvvm-c` bring their example, `minimal` brings none |
| `true` | The example, with its sources and tests |
| `false` | The pattern's structure and its README notes, without the example code |

`false` is the setting for a team that knows the pattern and wants the project's
own screens instead of a greeting. The generated `README.md` still describes the
pattern the project was created with, so the intent survives even when the
example does not.

## Why an example at all

A pattern described in a README is a pattern nobody follows. The generated
example is concrete code in the project's own module, with its own tests, so
the first real screen has something to be written *like*. The reasoning is in
[ADR-0004](adr/0004-architecture-overlay-generates-a-concrete-example.md).

Mechanically, the example is an **overlay**: it replaces the variant's screen at
the same paths rather than adding a second one beside it. That replacement is
declared, and resolved before the File Manifest sees it, which is why it is not
a `TEMPLATE_CONFLICT` (see [templates.md](templates.md)).

## Choosing

| | |
|---|---|
| Scratch project, reproduction case | `minimal` |
| Anything you intend to keep | `mvvm` |
| A UIKit app with real navigation | `mvvm-c` |
| You have your own conventions | `mvvm` with `includeExample: false`, or `minimal` |

The `standard` and `production` [presets](presets.md) both choose `mvvm` with
its example.
