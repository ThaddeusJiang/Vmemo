# E2E Testing (Agent First)

This directory contains Playwright end-to-end tests for Vmemo.

For day-to-day e2e work, use the skill as the single source of truth:

- `/.agents/skills/vmemo-e2e-testing/SKILL.md`

## Scope

- Author or update focused Playwright specs in `tests/`.
- Run only scoped tests by default.
- Use fix → rerun loop until acceptance criteria pass.

## Quick Start

Run from `others/e2e-test`:

```bash
bun install
bunx playwright install chromium
```

## Common Commands

```bash
# Headless (scoped)
bun run e2e -- tests/home-page.spec.ts

# UI mode (scoped)
bun run e2e:ui -- tests/home-page.spec.ts
```

Do not run the full suite unless explicitly requested.

## Runtime Targets

- Local dev server target: default `http://localhost:4000`
- Override target with `E2E_BASE_URL`

```bash
E2E_BASE_URL=http://localhost:4000 bun run e2e -- tests/home-page.spec.ts
```

For local prerequisites and execution flow, follow:

- `/.agents/skills/vmemo-e2e-testing/SKILL.md`

## CI Notes

- CI e2e workflow trigger label: `run-e2e-test`
- Snapshot update path and CI details are documented in the workflow and skill docs.

## Test Account

```text
email = "test@example.com"
password = "pass123456"
```
