# E2E Testing

This directory contains Playwright end-to-end tests written in TypeScript and executed with Bun.

## Prerequisites

- App is running at `http://localhost:4000`
- PostgreSQL and Typesense are available for the app
- Bun installed

## Install

Run from `e2e-test` directory:

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

Start the prod-like app container from `e2e-test/docker-compose.yml`.
This compose file now manages only `vmemo`; PostgreSQL and Typesense must already be available outside it.

```bash
docker compose -f docker-compose.yml up -d --pull never
```

Stop and remove the stack after testing:

```bash
docker compose -f docker-compose.yml down -v
```

By default, the app container connects to:

- PostgreSQL: `host.docker.internal:5432`
- Typesense: `host.docker.internal:8108`

Override `DATABASE_URL` or `TYPESENSE_URL` if your target services are elsewhere.

## Auth Setup

Playwright runs `globalSetup` before tests:

- log in once with the shared test account
- save authenticated storage state to `/tmp/vmemo-e2e-storage.json`

Seed or auth preparation must happen in the environment under test.

For CI, the workflow prepares the shared test user inside the running `vmemo` container.

Test files should reuse this authenticated state instead of embedding login flows in each spec.

## Run Tests

Run all e2e tests against the current target:

```bash
bun run e2e
```

Local default runs with visible browser UI (headed, recommended for human verification):

```bash
bun run e2e
```

Run a single test:

```bash
bun run e2e -- tests/upload-only.spec.ts
```

Run CI mode (headless):

```bash
bun run e2e:ci
```

Update Playwright visual baselines:

```bash
bun run e2e:update-snapshots
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
await expect(page).toHaveScreenshot()
await expect(page.getByRole("button", { name: "Save" })).toHaveScreenshot()
```

Commit the generated baseline snapshots so the same visual checks run locally and in CI.

Page-render visual assertions should run at both:

- `iPhone SE`
- `MacBook 13` size (`1280x800`)

## Test Account

```text
email = "test@example.com"
password = "password123456"
```

## CI Trigger

CI e2e workflow runs when the PR has label:

- `run-e2e-testing`

That single label runs the full e2e suite, including page-render visual assertions.

The same workflow also supports manual `workflow_dispatch` with a single checkbox:

- `update_snapshots`

Manual dispatch always runs the full e2e suite. The checkbox only controls whether the suite updates snapshots.

CI runs the same specs against a prod-like target:

- build image from current branch
- start `postgres` and `typesense` with GitHub Actions `services`
- start the app with `docker compose -f docker-compose.yml up -d`
- run Playwright tests against `http://localhost:4000`
- upload `test-results` and snapshot artifacts

Local development can run the same specs against either:

- an already running dev server
- the local Docker prod-like app from `e2e-test/docker-compose.yml` with external PostgreSQL and Typesense
