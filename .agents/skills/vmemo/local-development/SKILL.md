---
name: "Vmemo/local-development"
description: "Unified Vmemo local development workflow: setup-state check, reset decision, and temporary port conflict handling."
---

# Local Development

Trigger when the user asks for local `setup`, `reset`, `stop`, or environment validation.

Ignore worktree-specific concepts. Focus only on:
- whether environment is already setup
- whether reset is required
- temporary port remap when conflicts exist

## Decision flow

1. Run `mise trust && mise install`.
2. Ensure `.env` has required vars:
   - `DATABASE_URL`
   - `TYPESENSE_URL`
   - `MOONDREAM_URL`
3. Check setup state:
   - If deps missing or services unavailable, run `setup`.
   - If user explicitly requests clean rebuild, run `setup`.
   - If state is broken/corrupted, run `reset` then `setup`.
4. Before `docker compose up -d`, check host port conflicts.
5. If conflict exists, create/update `docker-compose.override.yml` with temporary ports and sync `.env` URLs to those ports.
6. Start services and continue workflow.

## setup

Use when environment is not ready or user asks setup:

1. `mix deps.get`
2. `docker compose up -d` (or `docker compose --profile test up -d` for local test infra)
3. Ensure `moondream-station` is running (`pgrep -f moondream-station` or start it in background)
4. `mix setup`

## reset

Use when environment is inconsistent, user asks reset, or setup repeatedly fails.

```bash
mix reset
```

## stop

```bash
docker compose down
pkill -f moondream-station || true
pkill -f "mix phx.server" || true
```

## Notes

- Do not run `build` or `start` unless explicitly requested.
- Since runtime config uses env-only URLs, fail fast if `DATABASE_URL` / `TYPESENSE_URL` / `MOONDREAM_URL` are missing.
- Temporary port handling must be done via `docker-compose.override.yml`; do not modify `docker-compose.yml`.
