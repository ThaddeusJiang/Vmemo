---
name: "Local Development"
description: "Skill for Vmemo local development workflows."
---

# Local Development Skill

Use this skill when the user asks to run local `reset`/`setup` workflows, rebuild local dependencies, or reinitialize development data.

## Common

Use `mise` as the single source of truth for local development environment, before any workflow, run: `mise trust && mise install`.

Before running any project script (`mix reset` / `mix setup`), ensure local dependencies are ready:

- Run `docker compose up -d` (postgres + typesense)
- Run `moondream-station` (directly or ensure it is already running)

```bash
docker compose up -d
pgrep -f moondream-station >/dev/null || moondream-station &
```

## Reset workflow

When the user asks to run `reset`, first run the Common dependency steps, then run `mix reset`.

```bash
mix reset
```

## Setup workflow

When the user asks to run `setup`, first run the Common dependency steps, then run `mix setup`.

```bash
mix setup
```

## Stop workflow

When the user asks to run `stop`, stop local services and related processes in this order:

```bash
docker compose down
pkill -f moondream-station || true
pkill -f "mix phx.server" || true
```

## Expected outcome

- Reset ensures local dependencies are ready before `mix reset`.
- Setup recreates Docker services and prepares local dependencies.
- Stop shuts down Docker services and local runtime processes.
- Runtime/toolchain is prepared before project scripts.

## Guardrails

- Keep workflow order as documented.
- Always run `mise trust` and `mise install` before project scripts.
- `reset`: run `docker compose up -d`, ensure `moondream-station` is installed/running, then run `mix reset`.
- `setup`: run `docker compose up -d`, ensure `moondream-station` is installed/running, then run `mix setup`.
- `stop`: run `docker compose down`, stop `moondream-station`, then stop `mix phx.server`.
- Use direct commands without `mise exec`.
- Do not run `build` or `start` commands unless explicitly requested.
- After code changes, run `mix dialyzer --format short` and fix all issues until clean.
