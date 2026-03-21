# 20260321-runtime-env-overrides

## Summary
- Align external service config so environment changes are applied through `config/runtime.exs`.

## Changes
- Added runtime overrides for `TYPESENSE_URL` and `TYPESENSE_API_KEY` in `config/runtime.exs` for all environments.
- Removed the duplicate prod-only Typesense override now that runtime handles it globally.
- Updated `AGENTS.md` to record the new guideline: environment-sensitive external service config should be overridden via runtime config.

## Notes
- `MOONDREAM_URL` and `MOONDREAM_API_KEY` were already using runtime overrides.
- Local `.env` still needs to be loaded by your shell, `mise`, or container env config before Mix starts.
