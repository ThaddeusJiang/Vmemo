---
name: "Local Development"
description: "Skill for Vmemo local development workflows."
---

# Local Development

Trigger when the user asks for local `setup`, `reset`, or `stop`.

## setup

Full reset from scratch: bring dependencies up, then `mix setup`.

1. `docker compose down -v`
2. `docker compose up -d` (dev Postgres + Typesense only). If you need local `mix test` against Docker, use `docker compose --profile test up -d` or `COMPOSE_PROFILES=test docker compose up -d` instead.
3. Ensure `moondream-station` is running (`pgrep -f moondream-station` or start it in background)
4. `mix setup`

## reset

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
- After code changes: `mix dialyzer --format short` until clean.
