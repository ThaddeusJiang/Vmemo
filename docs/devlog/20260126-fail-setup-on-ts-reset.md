# 2026-01-26 Fail setup on Typesense reset errors

## Context
- `mix setup` runs `ts.reset`, but Typesense failures were silently ignored.

## Changes
- Treat Typesense reset failures as errors by raising in `Vmemo.Ts` when requests fail.
- Allow missing collections during drop without failing the reset.

## Notes
- `mix setup` now stops if Typesense is unreachable or misconfigured.
