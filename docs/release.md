# Releasing

A pushed `v*` tag is the whole trigger, and the tag is the single source of the
version. Nothing in the repository carries a release number: `ScaffoldVersion`
says `0.0.0-dev` on `main`, and the release workflow stamps the tag's number in
before building. A binary that disagrees with its tag fails the release.

## Before tagging

1. **`main` is green.** Build and test, the e2e matrix, and lint.
2. **The CHANGELOG has a section for this version.** Rename `[Unreleased]` to
   `## [x.y.z] — YYYY-MM-DD`. That section becomes the GitHub Release notes
   verbatim, so it is written for someone deciding whether to upgrade — what
   changed, and why it changed.
3. **The spec issue for the version is satisfied.** Every ticket under it is
   closed, or explicitly moved.

```bash
git checkout main && git pull
# edit CHANGELOG.md
git commit -m "chore(release): x.y.z"
git push
```

## Tagging

```bash
git tag vx.y.z
git push origin vx.y.z
```

That is the entire release trigger. The workflow then, in order:

| Job | What it does |
|---|---|
| **Tests gate the release** | The same three gates as CI, plus the template sync check. Any failure stops the release before anything is built. |
| **Build and publish** | Stamps the version, builds a universal binary (arm64 + x86_64), proves both architectures are in it with `lipo`, packages a `.tar.gz` with a SHA256 beside it, and creates the GitHub Release with the CHANGELOG section as its notes. |
| **Release smoke test** | Downloads the **published artifact**, checks the checksum, checks the binary reports the tag's version, and generates and builds a real project with it. |

The smoke test runs against what a user downloads, not against the checkout.
That is the point of it: a release that builds from source and ships a broken
archive is a release that passed every other check.

## After the release

Update the Homebrew formula in
[`g761007/homebrew-tap`](https://github.com/g761007/homebrew-tap):

```ruby
url "https://github.com/g761007/xcode-project-scaffold/releases/download/vx.y.z/xscaffold-vx.y.z-macos-universal.tar.gz"
sha256 "<the published .sha256>"
```

Then verify the tap end to end, because the formula is the path most users
take:

```bash
brew uninstall xscaffold; brew untap g761007/tap
brew install g761007/tap/xscaffold
xscaffold --version                        # matches the tag
ls "$(brew --prefix)/share/zsh/site-functions/_xscaffold"
```

The formula asks the binary for its own completion scripts at install time, so
completions match whatever version was installed and never need bumping
separately.

## Release candidates

A tag with a SemVer pre-release identifier — `v0.9.0-rc.1` — goes through the
same pipeline, with two differences the hyphen decides on its own:

- The GitHub Release is marked **pre-release**, so it does not become "Latest
  release". That matters because the README's install link and a bare
  `gh release download` both resolve to whatever is latest: a candidate that
  claimed the slot would reach everyone who never asked for one.
- **The Homebrew formula is not updated.** `brew install` is the path most
  users take and it should stay on the last real release. Someone trying a
  candidate downloads the archive from the release page.

Otherwise nothing changes: the tag is still the whole trigger, the CHANGELOG
section named for it is still the release notes, and the smoke test still runs
against the published artifact.

The CHANGELOG section is named for the candidate — `## [0.9.0-rc.1]` — and
renamed to the final version when that ships, which is the same one-line edit
step 2 above already asks for.

## Versioning during 0.x

`xscaffold` follows Semantic Versioning, but the `0.x` series makes **no
compatibility promise**: the `scaffold.yml` schema, the CLI contract, the JSON
output and the exit codes may change without a migration path until 1.0.

In practice each minor is one spec issue's worth of scope, and patches are for
bugs found after a release — a project that generates and then fails to compile
is a patch, not a "known issue".

Stability guarantees, a deprecation policy and a template compatibility policy
arrive with 1.0. Until then, say so plainly rather than implying otherwise.

## If a release goes wrong

The tag is the only artifact that is hard to take back. A bad build can be
deleted with the release and re-cut, but a tag that has been pulled by someone
should not be moved — cut the next patch instead. That is cheaper than
explaining why two checkouts of the same tag differ.
