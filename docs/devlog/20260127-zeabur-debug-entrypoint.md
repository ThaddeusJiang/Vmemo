# 2026-01-27 Zeabur debug entrypoint

## Context

Zeabur startup probe failed with connection refused on port 4000.

## Changes

- Add a Docker entrypoint to validate required env vars and print startup info.
- Default `PHX_SERVER=true` when missing to avoid silent no-listen failures.
- Separate required vs optional env vars (warn for optional).
- Mark `TYPESENSE_*` and `MOONDREAM_URL` as required; only `OPENROUTER_API_KEY` is optional.

## Notes

This improves observability in container logs without exposing secrets.
