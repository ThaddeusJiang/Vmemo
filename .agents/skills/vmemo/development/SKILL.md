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
- Copy `AGENTS.override.md` from the main checkout using `cp`.
- Copy `.env` from the main checkout using `cp`.

## Setup

1. Run `mise trust && mise install`.
3. Check setup state:
   - If deps missing or services unavailable, run `mix setup`.
   - If state is broken/corrupted, run `mix reset` then `mix setup`.
4. Before `docker compose up -d`, check host port conflicts.
5. If conflict exists, create/update `docker-compose.override.yml` with temporary ports and sync `.env` URLs to those ports.
6. Start services and continue workflow.

## Test 

1. Run `docker compose --profile test up -d`.

## Check

1. Run `mix check`

## Notes
- Temporary port handling must be done via `docker-compose.override.yml`; do not modify `docker-compose.yml`.
