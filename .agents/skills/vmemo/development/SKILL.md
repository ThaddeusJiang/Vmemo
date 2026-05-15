---
name: "vmemo-development"
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

## Start Docker Compose

1. Run `docker compose up -d`.

## Setup mix

- Run `mise trust && mise install`.
- Run `mix setup`.

## Reset

- Run `mix reset`.

## Test 

1. Run `docker compose --profile test up -d`.
2. Default: run only modified test cases (for example `mix test test/path/to_case_test.exs:123` or targeted files).
3. When test files are modified, rerun only failed tests first with `mix test --failed`.
4. Run full test suite only when explicitly requested.
5. Run `docker compose --profile test down` to clean up.

## Check

- Run `mix check`.

## Self-review

- Run `mix format`.
- Run `mix check`.
- Run Dialyzer checks locally (for example `mix dialyzer` when configured).
- Run ElixirLS diagnostics in local editor/workspace and review warnings/errors.
- Fix all errors and warnings found by the checks above before finishing the task.

## Notes
- Temporary port handling must be done via `docker-compose.override.yml`; do not modify `docker-compose.yml`.
