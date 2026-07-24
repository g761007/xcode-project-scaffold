# Security Policy

## Supported versions

Only the latest release of the 0.x series receives fixes. There is no
backporting during 0.x.

## Reporting a vulnerability

Please report vulnerabilities privately through
[GitHub Security Advisories](https://github.com/g761007/xcode-project-scaffold/security/advisories/new)
rather than in a public issue. You can expect an acknowledgement within a week.

## Scope worth knowing about

- `xscaffold` executes external tools (`git`, `xcodegen`, `xcodebuild`, `open`)
  found on the `PATH`, and writes files only under the destination directory
  the user named (staged beside it, moved in atomically). Anything that lets a
  configuration file or template escape that boundary is a vulnerability —
  planned paths are checked, and a bypass of that check is exactly the kind of
  report we want.
- `scaffold.yml` is designed to be committed. Do not put secrets in it; the
  tool never asks for any, and a generated project's `.gitignore` cannot
  protect a file that was already committed.
