# E2E Testing

This directory contains Playwright end-to-end tests written in TypeScript and executed with Bun.

## Prerequisites

- App is running at `http://localhost:4000`
- PostgreSQL and Typesense are available for the app
- Bun installed

## Install

Run from `others/e2e-test` directory:

```bash
bun install
bunx playwright install chromium
```

## Target Environments

The same Playwright specs should work against both:

- local dev server
- prod-like Docker app

Select the target with `E2E_BASE_URL`. The default is `http://localhost:4000`.

## Dev Mode

Use this when the app is already running in your local dev environment.

Example:

```bash
E2E_BASE_URL=http://localhost:4000 bun run e2e
```

## Prod-Like Mode

Start the prod-like app stack from `others/e2e-test/docker-compose.yml`.
This compose file manages:

- `postgres-e2e`
- `typesense-e2e`
- `vmemo-e2e`
- `e2e-seed`

Build local e2e image first (native platform, do not force `linux/amd64` locally):

```bash
docker buildx build --file ../Dockerfile --tag thaddeusjiang/vmemo:e2e --load ..
```

Then start:

```bash
docker compose up -d --pull never
```

Stop and remove the stack after testing:

```bash
docker compose down -v
```

By default, `vmemo` resolves runtime connections as:

- `DATABASE_URL` (or fallback to `ecto://postgres:postgres@host.docker.internal:10003/vmemo_test`)
- `TYPESENSE_URL` (or fallback to `http://host.docker.internal:10004`)
- `TYPESENSE_API_KEY` (or fallback to `xyz`)

In prod-like mode, container startup runs:

- release migrations (`Vmemo.Release.migrate/0`)
- e2e SQL seed via `e2e-seed` service (`others/e2e-test/sql/seed_e2e.sql`)

## Auth Setup

Playwright runs `globalSetup` before tests:

- log in once with the shared test account
- save authenticated storage state to `/tmp/vmemo-e2e-storage.json`

Seed data is prepared by the dedicated `e2e-seed` service after app migrations complete.
No standalone `prepare-auth` step is required.

Test files should reuse this authenticated state instead of embedding login flows in each spec.

## Run Tests

Run all e2e tests against the current target:

```bash
bun run e2e
```

Local default runs in headless mode:

```bash
bun run e2e
```

Run a single test:

```bash
bun run e2e -- tests/upload-only.spec.ts
```

Update Playwright visual baselines:

```bash
bun run e2e:update-snapshots
```

## FAQ

### Why do local e2e tests fail unexpectedly?

The most likely cause is stale Docker volume data from previous runs.
Before running local e2e tests, clear e2e volumes first:

```bash
cd others/e2e-test && docker compose down -v
```

## Test Files

- `tests/*-page.spec.ts`: page-level e2e tests with built-in visual assertions

## Test Assets

Upload fixtures used by Playwright specs live under:

- `fixtures/upload-files/`

## Screenshots And Artifacts

Tests save screenshots to `/tmp`:

- `/tmp/vmemo-e2e-home-after-login.png`
- `/tmp/vmemo-e2e-login-success.png`
- `/tmp/vmemo-e2e-upload-success.png`

Playwright output is under:

- `test-results/`

For visual regression coverage, prefer Playwright screenshot snapshot assertions such as:

```ts
await expect(page).toHaveScreenshot();
await expect(page.getByRole("button", { name: "Save" })).toHaveScreenshot();
```

Commit the generated baseline snapshots so the same visual checks run locally and in CI.

For team collaboration, treat the CI prod-like run as the source of truth for visual pass/fail decisions. Local dev-server runs are useful for debugging and iteration, but they are not the shared baseline for accepting or rejecting visual changes.

Page-render visual assertions should run at both:

- `iPhone SE`
- `MacBook 13` size (`1280x800`)

## Test Account

```text
email = "test@example.com"
password = "pass123456"
```

## CI Trigger

CI e2e workflow runs when the PR has label:

- `run-e2e-test`

That single label runs the full e2e suite, including page-render visual assertions.

The same workflow also supports manual `workflow_dispatch` with a single checkbox:

- `update_snapshots`

When `update_snapshots` is enabled, the workflow runs Playwright in snapshot update mode and commits the generated baseline snapshots back to the selected branch automatically.

CI runs the same specs against a prod-like target:

- build image from current branch
- start the app with `docker compose -f others/e2e-test/docker-compose.yml up -d`
- startup runs release migrations, and `e2e-seed` inserts e2e fixture data
- run Playwright tests against `http://localhost:4000`
- upload Playwright HTML report artifact: `e2e-playwright-report-<run_id>`

When a CI run fails, open **Actions > failed run > Artifacts**, download the report zip,
extract it, then serve it locally:

```bash
bunx playwright show-report playwright-report
```

Do not rely on directly opening `index.html` from Finder, as Playwright report features
require a local web server.

### Typesense Stability In CI

Image embedding is always enabled.

To avoid flaky first-request model downloads during test execution, the app now warms up the
Typesense embedding model in the ts migration entrypoints (`mix ts.migrate` and release migrate)
right after schema migrations.

This means both local Docker runs and GitHub Actions start from the same state before Playwright
tests begin.

Local development can run the same specs against either:

- an already running dev server
- the local Docker prod-like app from `others/e2e-test/docker-compose.yml` with PostgreSQL and Typesense

Use local runs to debug quickly. Use CI results to decide whether visual changes are acceptable for the team.
