# Optimize Elixir checks setup time

## Background
The CI step `Setup DB and Typesense` was slow and duplicated database setup work.
`mix test` already runs the `test` alias, which includes `ash_postgres.create --quiet` and `ash.migrate --quiet`.

## Changes
- Added `actions/cache@v4` for `deps` and `_build` in `.github/workflows/elixir-checks.yml`.
- Renamed setup step to `Setup Typesense` and kept only `mix ts.setup`.
- Kept `mix test` as the single place to run DB create/migrate for tests.

## Why this helps
- Avoids running DB create/migrate twice in the same workflow.
- Reduces cold compile overhead on repeated CI runs through cache reuse.

## Notes
- Typesense setup is still executed before tests to ensure required collections/migrations exist.
- This is a workflow-only optimization and does not change application runtime behavior.
