# The frozen contracts

Three contracts are frozen for 1.0: the `scaffold.yml` schema, the CLI, and the
JSON output. This page says what is in each of them, what is deliberately left
out, and which test fails when one changes.

Changing a frozen contract means changing a test written to fail on that
change. That is the point — see
[the deprecation policy](deprecation-policy.md) for what a change costs.

> **Status:** schema frozen. CLI and JSON are freeze candidates; their sections
> below say so.

## Schema — frozen

Every field of `scaffold.yml`, its default and its allowed values. Documented
in [configuration.md](configuration.md); published as a JSON Schema at
`Schemas/scaffold.schema.json`.

### What is frozen

- Every property path a document may state — 83 of them, counting nested and
  list-item paths.
- Every field's default.
- Every closed vocabulary: platforms, interfaces, lifecycles, architectures,
  generators, test frameworks, dependency modes, CI providers, presets.
- Every `ValidationCode`, and its `XS0xxx` / `XS1xxx` category.
- The wire form: key order, and the quoting of version-like values.
- `schemaVersion`, and which versions a binary accepts.

### What is not

- The *messages* validation produces. Codes are contract; their English is not.
- Which values are *supported* as opposed to *decodable*. `product.type` accepts
  `framework` and refuses it as `XS0003`; a later release may generate it. That
  boundary moves by design, and moving it is not a breaking change.

### What holds it

| Test | Pins |
|---|---|
| `SchemaFreezeTests` | Three golden documents round-trip byte for byte, and together state every path the published schema allows. A field added to the schema fails until a golden covers it. |
| `YAMLContractTests` | The default document, and the quoting of version-like values. |
| `JSONSchemaConsistencyTests` | The published JSON Schema's vocabularies equal the types'. |
| `ValidationCodeTests` | Every code is well formed and in the right category. |
| `SkillReferenceTests` | Both field references document every code and every allowed value. |
| `SchemaVersionTests` | A version outside `capabilities.schemaVersions` is refused. |

The golden documents are a *set* rather than one document, because the schema
has fields that exclude each other — a package states exactly one of `from`,
`exact`, `branch` or `revision`. One document cannot state them all, and a
contract that only pins what one document happens to state is not frozen.

## CLI — freeze candidate

Commands, flags, arguments and exit codes. Documented in
[cli-reference.md](cli-reference.md).

### What is frozen

- Every command and subcommand name.
- Every flag's name, whether it takes a value, and its default.
- Every exit code's number and meaning.
- The rule that `--output json` puts one document on stdout and nothing else,
  with everything a person would read on stderr.

### What is not

- Help text, and the `discussion` block under each command.
- The wording of any error.
- The order and phrasing of the interactive `new` questions, and the menu.
- `--generate-completion-script`, which ArgumentParser provides and hides.

### What holds it

`Tests/CommandLineTests/` — the suites that run the built binary — plus
`ExitCodeTests`. The audit that turns this into a freeze is #133.

## JSON output — freeze candidate

`CommandOutput` and everything reachable from it. Documented in
[cli-reference.md](cli-reference.md#machine-readable-output).

### What is frozen

- Every key, its type, and the condition under which it appears. A key that is
  absent is never `null`.
- Every `ScaffoldExitCode` number, `ScaffoldErrorCode` string, `ValidationCode`
  string and `ScaffoldPhase` string.
- The encoding: one line, keys sorted, slashes unescaped.

### What is not

- `message`, and `error.message`. Both are prose.

### What holds it

`CommandOutputContractTests`, `ErrorContractTests` (both the schema-level and
the binary-level suites), and `ExitCodeTests`. The audit is #134.

## Adding to a frozen contract

Adding is not breaking, and the tests are built so that adding is *visible*
rather than silent:

1. Add the field, flag or key.
2. The freeze test fails, because the new thing is in no golden document and no
   pinned table.
3. Add it to the golden, or to the table, in the same commit.

Step 2 is the design. A contract you can extend without noticing is one that
drifts.
