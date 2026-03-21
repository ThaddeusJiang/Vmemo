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

## Run Tests

Run all e2e tests:

```bash
cd test/e2e
bun run test
```

Local default runs with visible browser UI (headed, recommended for human verification):

```bash
cd test/e2e
bun run test
```

Run a single test:

```bash
cd test/e2e
bun run test -- tests/register-login.spec.ts
```

Run CI mode (headless):

```bash
cd test/e2e
bun run test:ci
```

## Test Files

- `tests/register-login.spec.ts`: register and login, then save auth state
- `tests/upload-only.spec.ts`: upload with existing auth state
- `tests/login-upload.spec.ts`: combined login/register + upload flow

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
- start stack with `_prod/docker-compose.yml`
- run Playwright tests against `http://localhost:4000` with `bun run test:ci`
