# Move Typesense migrate into test alias

## Background
`elixir-checks.yml` had a dedicated `Setup Typesense` step before `mix test`.
To simplify CI flow and keep test setup centralized, Typesense migration should be part of the test alias.

## Changes
- Updated `mix.exs` test alias to include `ts.setup`:
  - from: `ash_postgres.create --quiet`, `ash.migrate --quiet`, `test`
  - to: `ash_postgres.create --quiet`, `ash.migrate --quiet`, `ts.setup`, `test`
- Removed standalone `Setup Typesense` step from `.github/workflows/elixir-checks.yml`.

## Why this helps
- Keeps test environment setup in one place (`mix test` alias).
- Avoids duplicated setup orchestration between workflow and Mix aliases.

## Notes
- `ts.setup` remains idempotent through migration implementation safeguards.
- This change is CI/setup flow only and does not alter product runtime behavior.
