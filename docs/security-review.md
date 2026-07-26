# Security review

Carried out for v0.9 (#135), over the four surfaces the spec names. This
records what was looked at, what was found, and what was decided — including
the things deliberately left alone.

The threat model that matters is **a `scaffold.yml` you did not write**: from a
template repository, from a colleague's pull request, from an AI agent. The
document is meant to be read and reviewed before it generates anything — the
save-now-generate-later flow exists for that — so the question throughout is
whether a document can do something a reader of it would not predict.

A `scaffold.yml` you wrote yourself is not a threat: everything it can do, you
could have done directly.

## 1. Secrets do not land on disk

**Looked at:** the `secrets` section, the generated `Secrets.xcconfig` pair,
`.gitignore`, `--output json`, `--resolved-config`, and the interactive
preview.

**Found:** the design holds. `scaffold.yml` has no field for a real secret
value — only a key name and an example — and that absence is the mechanism, not
an oversight. Both `Secrets.example.xcconfig` and the initial
`Secrets.xcconfig` are generated from the examples so that a fresh clone
builds; only the real file is git-ignored.

**Decided:** no change. One observation worth recording: the *example* value is
free text and is written verbatim into an xcconfig, which is how finding 3
below reached it.

## 2. External command execution

**Looked at:** `ProcessRunner`, `SystemProcessRunner.locate`, and every
`PlannedCommand` the builder produces.

**Found:** no shell is involved anywhere. Commands run through `Process` with
an `executableURL` and an `arguments` array, so a shell metacharacter in a
project name, a path or a pod name is an ordinary character to the child
process. `locate` walks `PATH` itself and skips empty entries — Swift's
`split` omits them by default — so the classic "empty `PATH` component means
the current directory" hazard does not apply, which matters because commands
run *in the destination directory*.

**Decided:** no change. A test now states the property rather than leaving it
to be re-derived.

## 3. Template rendering — **two real findings, both fixed**

**Looked at:** every user-controlled string that reaches a generated file, and
what kind of file it reaches. Placeholder substitution is plain string
replacement, and the outputs are Swift sources, YAML, a plist, a `Makefile`,
xcconfigs, a Podfile and a Gemfile.

### 3a. A newline made one reviewed line into two settings

```yaml
environments:
  - name: development
    configuration: Debug
    values:
      API_BASE_URL: "https://x\nOTHER_LDFLAGS = -whatever"
```

An xcconfig is `KEY = value` per line, so this generated **two** build
settings. The same worked through `secrets.keys[].example`, and through any
other free-text field — `organizationName` had never been constrained at all.

A reviewer reading the YAML sees one setting. That is the definition of a
document doing something its reader would not predict.

**Fixed** as `XS1305`: a control character anywhere in the document is refused.
Checked over the whole document rather than field by field — a list of fields
is a list that goes stale, and there is no field where a control character
means anything.

### 3b. A Podfile is Ruby, and xscaffold runs it

```yaml
pods:
  - name: "a' + system('id') + '"
    version: "1.0"
```

rendered as

```ruby
pod 'a' + system('id') + '', '1.0'
```

which is valid Ruby. `pod install` executes the Podfile, and **xscaffold runs
`pod install` itself**, immediately after generating it. So a `scaffold.yml`
was arbitrary code execution on whoever generated from it — with no newline
needed, so 3a's rule would not have stopped it.

The same reached `sources`, every `git`/`tag`/`branch`/`commit`/`path` value,
and the Gemfile's pinned CocoaPods version.

**Fixed** in the renderer rather than the validator: every value interpolated
into a Ruby single-quoted literal escapes `\` and `'`, which are the only two
characters Ruby reads inside one. Escaping is complete where a blocklist would
be one character short, and it does not refuse a URL that legitimately contains
a quote.

Verified by loading a generated Podfile in Ruby with the CocoaPods DSL stubbed
out: the payload arrives as an inert string and `system` never runs.

### What was left alone

`PRODUCT_DISPLAY_NAME` and similar values reach `project.yml` unescaped, and
XcodeGen writes them into the plist. XcodeGen escapes what it writes, and the
value is a plain YAML scalar in a position where YAML cannot be broken by its
contents. **No change**, and no newline can get there now.

## 4. Credential masking

**Looked at:** `CredentialMasking`, and every output the v0.8 error contract
added — `error.message`, `error.command`, `error.path` — since masking predates
them.

**Found:** masking applies at the output boundary, and the error object's
message is produced by the same `description` that the text form prints, so it
inherits the masking already asserted for log output and JSON.

**Decided:** no change; a test now covers the error fields specifically, so the
next output channel added has to answer the same question.

## What this review did not cover

- The generated project's own dependencies. `xscaffold` writes a Podfile and a
  `project.yml`; what those pull in is the project's business, and pinning
  versions is what `bundler` and `exact` exist for.
- Supply chain of `xscaffold` itself — two dependencies (ArgumentParser, Yams),
  both pinned by `Package.resolved`.
- Signing and notarization, which are #136 and need credentials this review had
  no access to.
