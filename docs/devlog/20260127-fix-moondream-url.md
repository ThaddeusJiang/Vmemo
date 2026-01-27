# 2026-01-27 fix moondream url

## Context
- Moondream query threw `FunctionClauseError` from `URI.parse/1` when `MOONDREAM_URL` was missing.
- `docker-compose.local.yml` used `MOONDREAMN_URL`, so the env var was never set.

## Changes
- Fix typo in `docker-compose.local.yml` to `MOONDREAM_URL`.
- Add a safe fallback for `:moondream_url` in `config/runtime.exs` to avoid nil.

## Notes
- Restart the app container after updating env vars.
