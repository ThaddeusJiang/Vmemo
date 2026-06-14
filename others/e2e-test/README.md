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

# Image display performance probe for list and detail pages
E2E_BASE_URL=http://localhost:4000 bun run perf:images
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

## Image Performance Probe

`bun run perf:images` verifies the `/images` list page and the first image detail page against a running Vmemo target and prints a JSON report with:

- list/detail image ready time
- `/storage/v1` response status, duration, content type, server, and bytes
- browser image resource timing and decoded dimensions

The default storage image response budget is 1s. Run `mix storage.warm_images` before the probe when measuring an existing dataset, because cold derivative generation is a warmup/backfill cost rather than normal page-load budget. Use `--limit 100` for batched warmup on large storage.

```bash
PHOTOS_INDEX_READY_BUDGET_MS=3000 \
STORAGE_IMAGE_RESPONSE_BUDGET_MS=1000 \
PHOTOS_INDEX_MIN_IMAGES=1 \
E2E_BASE_URL=http://localhost:4000 \
bun run perf:images
```

The report is also attached to the Playwright output as `photos-index-image-performance.json`.
Failed storage responses are included in `failedStorageResponses` for data hygiene debugging, while the 1s budget is enforced against successful image responses.

## CI Notes

- CI e2e workflow trigger label: `run-e2e-test`
- Snapshot update path and CI details are documented in the workflow and skill docs.

## Test Account

```text
email = "test@example.com"
password = "pass123456"
```
