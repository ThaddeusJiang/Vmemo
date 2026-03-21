# E2E Testing

This directory contains Playwright end-to-end tests written in TypeScript and executed with Bun.

## Prerequisites

- App is running at `http://localhost:4000`
- PostgreSQL and Typesense are available for the app
- Bun installed

## Install

```bash
cd test/e2e
bun install
bunx playwright install chromium
```

## Start App Stack

Start the production-like Docker stack used by e2e:

```bash
docker compose -f test/e2e/docker-compose.yml up -d --pull never
```

Stop and remove the stack after testing:

```bash
docker compose -f test/e2e/docker-compose.yml down -v
```

The compose file is self-contained and must not depend on `_prod/`.
Default test-only placeholder env values are defined directly in `test/e2e/docker-compose.yml`.

## Auth Setup

Playwright runs `globalSetup` before tests:

- log in once with the shared test account
- save authenticated storage state to `/tmp/vmemo-e2e-storage.json`

For CI, the workflow prepares the shared test user before Playwright by running:
`mix run priv/repo/seeds/test_users.exs` inside the running `vmemo` container.

Test files should reuse this authenticated state instead of embedding login flows in each spec.

## Run Tests

Run all e2e tests:

```bash
cd test/e2e
bun run e2e
```

Local default runs with visible browser UI (headed, recommended for human verification):

```bash
cd test/e2e
bun run e2e
```

Run a single test:

```bash
cd test/e2e
bun run e2e -- tests/upload-only.spec.ts
```

Run CI mode (headless):

```bash
cd test/e2e
bun run e2e:ci
```

## Test Files

- `tests/upload-only.spec.ts`: authenticated upload flow smoke test

## Screenshots And Artifacts

Tests save screenshots to `/tmp`:

- `/tmp/vmemo-e2e-home-after-login.png`
- `/tmp/vmemo-e2e-login-success.png`
- `/tmp/vmemo-e2e-upload-success.png`

Playwright output is under:

- `test/e2e/test-results/`

## Test Account

```text
email = "test@example.com"
password = "password123456"
```

## CI Trigger

CI e2e workflow runs only when PR has label:

- `run-e2e-testing`

CI e2e uses Docker image startup flow (production-like) instead of `mix phx.server`:

- build image from current branch
- start stack with `test/e2e/docker-compose.yml`
- run Playwright tests against `http://localhost:4000` with `bun run e2e:ci`
