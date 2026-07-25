# CocoaPods

CocoaPods support exists for the teams whose dependency story is tied to
internal infrastructure. If you have a free choice, use
[SPM](dependencies.md) instead.

```yaml
dependencyManagement:
  mode: cocoapods
  cocoapods:
    pods:
      - name: SnapKit
        version: "5.7.1"
```

## What a run does

With pods declared, generation gains two steps after XcodeGen:

```text
xcodegen generate            produce Ledger.xcodeproj from project.yml
pod install                  produce Ledger.xcworkspace, integrating the pods
```

`xscaffold` writes the Podfile, runs the install, and then **verifies the
workspace exists**. `pod install` can return success and produce nothing —
possible with a degenerate Podfile — and finding that out now is better than
finding it out from the first `xcodebuild`.

`doctor` requires CocoaPods exactly when the configuration reads pods, and
requires Bundler instead when the configuration uses it.

## The project becomes a workspace

This is the part that surprises people coming from an SPM project. Once pods are
read, the container is `<name>.xcworkspace`, and everything follows it: the
generated `Makefile`'s `build`, `test` and `open` targets, the GitHub Actions
workflows, and `--validate-build`. Opening the `.xcodeproj` directly gives a
project that does not link its pods.

## Declaring a pod

Exactly one source per pod — `version`, `path`, or `git` with one of `tag`,
`branch` or `commit`:

```yaml
    pods:
      - name: SnapKit
        version: "5.7.1"
      - name: InternalKit
        git: https://internal.example.com/internalkit.git
        tag: "2.1.0"
      - name: LocalKit
        path: ../LocalKit
```

Two sources, or none, is a validation error.

## Bundler

```yaml
    bundler:
      enabled: true
      cocoapodsVersion: "1.16.2"    # omit to take whatever resolves
```

Bundler puts a `Gemfile` beside the Podfile and changes the install sequence:

```text
bundle install               resolve the Gemfile
bundle exec pod install      install pods with the CocoaPods it names
```

Every machine and every CI run then installs pods with the same CocoaPods,
rather than with whichever one happens to be on the `PATH`. That is the whole
point of it for a team, and `cocoapodsVersion` is the team's number to choose —
omitted, the Gemfile takes whatever `bundle install` resolves.

`doctor` follows: with Bundler it requires `bundle` and stops requiring `pod`,
because `bundle exec` provides that one itself.

The `production` preset switches Bundler on for a project that reads pods,
during normalization. See [presets.md](presets.md).

## Private specs repositories

```yaml
    sources:
      - https://internal.example.com/specs.git
      - https://cdn.cocoapods.org/
```

**Order is preserved.** A private specs repo listed before the public CDN
resolves internal pods first, which is the reason to list it at all. An empty or
absent `sources` means no `source` line in the Podfile, which is CocoaPods' own
CDN default.

### Credentials

A credential embedded in a source URL is **masked everywhere `xscaffold` prints
it** — log output, `--output json`, validation messages — and is **not masked in
the Podfile**, which needs the real URL to work.

That asymmetry is deliberate, and it is not a substitute for keeping the
credential out of the file. A committed `scaffold.yml` with a password in a URL
is a password in everyone's clone; use a specs repo your team authenticates to
by SSH or by netrc, and keep the secret out of the document.

## A complete enterprise configuration

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
    bundler:
      enabled: true
      cocoapodsVersion: "1.16.2"
    sources:
      - https://internal.example.com/specs.git
      - https://cdn.cocoapods.org/
    pods:
      - name: InternalKit
        git: https://internal.example.com/internalkit.git
        tag: "2.1.0"
```

The whole file is at
[`examples/ios-enterprise-cocoapods.yml`](../examples/ios-enterprise-cocoapods.yml).

## Troubleshooting

| What you see | What it means |
|---|---|
| `COCOAPODS_NOT_INSTALLED`, exit `10` | `pod` is not on the PATH. `brew install cocoapods`. |
| `BUNDLER_NOT_INSTALLED`, exit `10` | `bundle` is not on the PATH. `gem install bundler`. |
| `POD_INSTALL_FAILED`, exit `8` | The install ran and failed. Run it again with `--verbose` in the destination; its output names the pod. |
| `WORKSPACE_NOT_GENERATED`, exit `7` | The install reported success and produced no workspace. Usually a Podfile that integrates nothing. |

The project is left on disk in all but the first two cases: generation
succeeded, and what failed is the install on top of it.
