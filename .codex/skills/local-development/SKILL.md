---
name: "local-development"
description: "Skill for Vmemo local development workflows."
---

# Local Development Skill

Use this skill when the user asks to reset local development state, rebuild local dependencies, or reinitialize development data.

## Reset workflow

When the user asks to run `reset`, execute these steps in order:

1. Stop `mix phx.server`.
2. Run `docker compose down -v` to remove containers and volumes.
3. Run `docker compose up -d` to restart required services.
4. Run `mix setup`.

## Command sequence

```bash
pkill -f "mix phx.server" || true
docker compose down -v
docker compose up -d
mix setup
```

## Expected outcome

- Local database is recreated from current definitions.
- Typesense definitions are initialized from project setup tasks.
- Local development smoke testing data is reloaded by `mix setup`.

## Guardrails

- Always keep this exact order for reset.
- Do not skip `mix setup` after containers are recreated.
- Do not run `build` or `start` commands unless the user explicitly asks.
