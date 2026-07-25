# Example configurations

Four `scaffold.yml` files, each a project someone might actually be starting.

They are not what `xscaffold config example` prints. That command answers "give
me every field with its resolved value, so I can see what I am about to
generate"; these answer the question after it — what the file looks like once
somebody has decided what they want and deleted the rest. Every field here is
one whose value was chosen. Everything else is left out and takes its default,
which is how a `scaffold.yml` in a repository tends to end up.

| File | What it shows |
|---|---|
| [`ios-swiftui-minimal.yml`](ios-swiftui-minimal.yml) | The smallest file that generates something: three required fields and nothing else |
| [`ios-uikit-mvvm-c.yml`](ios-uikit-mvvm-c.yml) | A coordinator-based UIKit app with SPM packages and two environments |
| [`macos-appkit-standard.yml`](macos-appkit-standard.yml) | A preset carrying most of it, with two fields overridden against the preset |
| [`ios-enterprise-cocoapods.yml`](ios-enterprise-cocoapods.yml) | A private specs repo, Bundler pinning, mixed dependencies, extensions and CI |

Each one:

```bash
xscaffold validate examples/ios-uikit-mvvm-c.yml
xscaffold plan --config examples/ios-uikit-mvvm-c.yml --files
xscaffold generate --config examples/ios-uikit-mvvm-c.yml --destination /tmp/Demo --yes
```

`xscaffold plan --config <file> --resolved-config` shows what every field left
out here resolves to.
