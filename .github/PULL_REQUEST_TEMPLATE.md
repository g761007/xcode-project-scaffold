## What

<!-- What changes, and why. Link the issue this finishes with "Closes #N". -->

## Tests

<!-- What proves it: which suites cover it, what you ran locally, and anything
     deliberately not covered (say so rather than leaving it to be found). -->

## Checklist

- [ ] `swift test` passes and `make lint` is clean
- [ ] CLI contract changes (flags, exit codes, JSON fields) update the contract
      tests and the README in this PR
- [ ] New terminology is in `CONTEXT.md`; decisions worth recording have an ADR
- [ ] Template changes ran `make templates` and committed the regenerated file
