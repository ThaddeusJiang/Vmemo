---
name: "vmemo-development-skill"
description: "Unified Vmemo local development workflow: setup-state check, reset decision, and temporary port conflict handling."
---

# Vmemo Development Skill

This skill is the source of truth for local environment bootstrap commands, reset flow, and temporary port-conflict handling.

Focus only on:
- whether environment is already setup
- whether reset is required
- temporary port remap when conflicts exist

## Prepare
- Run `mise trust && mise install`.
- Copy `AGENTS.override.md` from the main checkout using `cp`.
- Copy `.env` from the main checkout using `cp`.

## Start Docker Compose

1. Before `docker compose up -d`, check host port conflicts.
2. If conflict exists, create/update `docker-compose.override.yml` with temporary ports and sync `.env` URLs to those ports.
3. Start services and continue workflow.

## Setup

Check setup state:
- If deps missing or services unavailable, run `mix setup`.
- If state is broken/corrupted, run `mix reset` then `mix setup`.

## Test 

1. Run `docker compose --profile test up -d`.
2. Run `mix test`.
3. Run `docker compose --profile test down` to clean up.

## Check

- Run `mix check`.

## Notes
- Temporary port handling must be done via `docker-compose.override.yml`; do not modify `docker-compose.yml`.
