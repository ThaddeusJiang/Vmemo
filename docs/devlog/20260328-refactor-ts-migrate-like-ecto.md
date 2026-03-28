# Refactor Typesense migrate to Ecto-like pending execution

## Background
`mix test` should remain idempotent even when `ts.setup` runs on every test invocation.
The previous `ts.migrate` implementation re-evaluated all migration files each run and relied on per-migration idempotence guards.

## Changes
- Added Typesense migration tracking collection: `_ts_schema_migrations`.
- Updated `Vmemo.Ts.migrate/0` to:
  - ensure migration tracking collection exists,
  - load applied migration versions,
  - execute only pending migration files,
  - record each version after successful execution.
- Updated `Vmemo.Ts.reset/0` to also drop `_ts_schema_migrations`.
- Added unit tests for `Vmemo.Ts.pending_migrations/2` in `test/vmemo/ts_test.exs`.

## Why this helps
- Makes Typesense migration behavior closer to Ecto migration semantics.
- Reduces repeated work and lowers accidental non-idempotent re-execution risk.
- Keeps `mix test` setup deterministic when `ts.setup` is included in the test alias.

## Notes
- Existing migration files are still expected to be safe if re-run, but now the normal path is pending-only execution.
- This change affects migration orchestration only; domain data behavior is unchanged.
