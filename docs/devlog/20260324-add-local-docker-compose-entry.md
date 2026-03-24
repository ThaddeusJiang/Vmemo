# 2026-03-24 Add local docker compose entry

## Summary

Added a `_local` Docker Compose entry so the full app can run from an isolated local directory based on `docker-compose.example.yml`.

## Changes

- added `_local/docker-compose.yml` with the `vmemo`, `postgres`, and `typesense` services
- kept the app build context at the project root while moving `.env`, `storage`, and data volumes under `_local/`
- updated the Docker run guide to use `_local/docker-compose.yml` for one-off local container tasks

## Files

- `_local/docker-compose.yml`
- `docs/build_and_run.md`
