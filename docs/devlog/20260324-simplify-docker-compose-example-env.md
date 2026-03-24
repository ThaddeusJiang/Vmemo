# 2026-03-24 Simplify docker compose example env

## Summary

Reduced `docker-compose.example.yml` environment overrides so the example is more fixed and easier to use.

## Changes

- switched the app service from a remote image reference to building from the local `Dockerfile`
- fixed the published port instead of exposing `VMEMO_*` overrides
- switched `DATABASE_URL` and `TYPESENSE_URL` to the bundled `postgres` and `typesense` services
- added `env_file: .env` for `vmemo`
- kept only external API credentials and endpoints flowing from `.env`
- inlined the remaining stable runtime values directly in the compose example
- kept `.env.example` as a full variable index and commented out values that are not typically needed
- restored `PORT` in compose as a commented override example instead of deleting it outright

## Files

- `docker-compose.example.yml`
