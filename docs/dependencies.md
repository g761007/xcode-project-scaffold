# Dependencies

`dependencyManagement.mode` is `none`, `spm`, `cocoapods` or `mixed`. SPM is the
default recommendation; [CocoaPods](cocoapods.md) exists for the teams that need
it, and `mixed` runs both.

```yaml
dependencyManagement:
  mode: spm
  spm:
    packages:
      - name: Alamofire
        url: https://github.com/Alamofire/Alamofire.git
        from: "5.9.0"
        products:
          - name: Alamofire
            targets: [MyApp]
```

## Declaring a package

| Key | Meaning |
|---|---|
| `name` | The package's name, as SPM knows it. |
| `url` | Where it is. |
| `from` / `exact` / `branch` / `revision` | The requirement. **Exactly one.** |
| `products` | Which products go into which targets. |

Stating two requirements, or none, is a validation error rather than a guess:
`from: "5.9.0"` and `exact: "5.9.1"` on the same package have no sensible
combined meaning.

```yaml
    packages:
      - name: swift-collections
        url: https://github.com/apple/swift-collections.git
        exact: "1.1.0"
        products:
          - name: Collections
            targets: [MyApp]
      - name: some-fork
        url: https://github.com/example/some-fork.git
        branch: main
        products:
          - name: SomeFork
            targets: [MyApp, MyAppTests]
```

`products[].targets` names targets in the generated project — the app target is
your project's name, the unit test target is `<name>Tests`, and the UI test
target, if you have one, is `<name>UITests`. A product listed against a target
that does not exist is refused before anything is written.

## What happens at generation time

Packages land in `project.yml` as `packages:` and as target dependencies.
XcodeGen writes them into the `.xcodeproj`, and **Xcode resolves them on first
build** — `xscaffold` never runs a resolution itself, so generation does not
need the network and does not produce a `Package.resolved`.

That is why a package URL that does not exist generates a project fine and
fails on first build: the check belongs to the resolver, and pretending
otherwise would mean a generator that needs network access.

## Mixed mode

`mixed` runs SPM and CocoaPods together. The one rule it enforces is that the
same library must not arrive through both:

```yaml
dependencyManagement:
  mode: mixed
  spm:
    packages:
      - name: swift-log
        url: https://github.com/apple/swift-log.git
        from: "1.5.0"
        products:
          - name: Logging
            targets: [Ledger]
  cocoapods:
    pods:
      - name: InternalKit
        version: "2.1.0"
```

Because pods are read, the project becomes a **workspace** — build, test and
open all go through `Ledger.xcworkspace` from then on. See
[cocoapods.md](cocoapods.md).

## Declaring nothing

`mode: none` is the default, and declaring packages under it is a validation
error rather than a silent no-op: a file that lists three packages and generates
a project with none is a file whose author will lose an afternoon.

## Where to look next

- [cocoapods.md](cocoapods.md) — Podfile generation, private specs repos,
  Bundler, and the workspace rule.
- [configuration.md](configuration.md#dependencymanagement) — every field and
  its default.
- [`examples/ios-uikit-mvvm-c.yml`](../examples/ios-uikit-mvvm-c.yml) — SPM in
  a real file.
