# Contributing

Thanks for considering a contribution. This project is early (0.x) and moves
quickly; this document is what you need to be productive in it.

## Setup

```bash
git clone https://github.com/g761007/xcode-project-scaffold.git
cd xcode-project-scaffold
make build && make test
```

You need macOS with Xcode 26.x and a Swift 6 toolchain. `make e2e` additionally
needs `xcodegen` and a git identity; `make lint` needs `swiftlint` and
`swiftformat` (`brew install xcodegen swiftlint swiftformat`).

## Before you write code

- **Read [`CONTEXT.md`](CONTEXT.md).** It is the project glossary; use its
  words, and do not introduce a synonym for something that already has a name.
  If your change needs a new term, add it there in the same commit.
- **Skim [`docs/adr/`](docs/adr/).** Decisions that look odd usually have a
  record; a PR that re-litigates one without new information will be pointed
  at it.
- **Check the issues.** Work is tracked in GitHub Issues; roadmap-sized tickets
  reference the spec issue for their release.

## The shape of the codebase

| Target | What lives there |
|---|---|
| `ScaffoldSchema` | The contract: configuration, plan, output and exit-code types. No behaviour. |
| `ScaffoldCore` | Everything the tool does: parsing, validation, planning, execution, prompting. |
| `xscaffold` | The CLI: flags, reporting, and the mapping from failures to exit codes. |

Two seams make the whole tool testable, and every subprocess and every
interactive question must go through them: `ProcessRunner` (external commands)
and `Prompter` (terminal I/O). Tests drive them with `FakeProcessRunner` and
`ScriptedPrompter`; nothing in the test suite launches a real tool or needs a
real terminal.

Templates under `Templates/` are compiled into the binary; after editing them
run `make templates` and commit the regenerated Swift file, or CI will fail the
sync check.

## Tests

`swift test` must pass, and `make lint` must be clean, before a PR is opened.

- Tests assert **external behaviour**: CLI output, exit codes, JSON documents,
  what lands on disk — not internal call order.
- The CLI binary contract suites (`Tests/CommandLineTests/`) run the real
  built binary; everything that writes passes `--skip-git --skip-generate` so
  the suite passes on a machine with neither tool installed.
- Interactive flows are covered with `ScriptedPrompter` at the unit level; the
  contract suites cover the refusals (no terminal, no `--output json`).

## Pull requests

- Branch from `main`; one concern per PR.
- Commit messages follow the existing convention: a conventional-commit title
  (`feat(cli): …`, `fix(core): …`, `docs: …`), a body that explains *why* in
  prose, and `Closes #N` when the PR finishes an issue.
- CI must be green: build and tests, the e2e matrix, and lint.
- CLI contract changes (flags, exit codes, JSON fields) must update the
  contract tests and the README in the same PR.

## Reporting bugs

Use the bug-report template — it asks for the versions, the command, the
`scaffold.yml` and the `plan --output json` output because those five things
answer most questions without a round trip.
