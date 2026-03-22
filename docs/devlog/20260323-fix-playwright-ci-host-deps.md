# Fix Playwright CI Host Dependencies

## Goal

Fix e2e CI failure where Playwright browsers cannot start because the GitHub Actions host is missing required Linux libraries.

## Changes

- Updated `.github/workflows/e2e-tests.yml`.
- Replaced Playwright install step:
  - from: `bunx playwright install`
  - to: `bunx playwright install --with-deps`
- Kept browser installation in the existing `e2e-test` working directory so installed binaries match the local workspace setup.

## Why

`playwright install` downloads browser binaries only.
`playwright install --with-deps` also installs required host packages on Ubuntu runners, preventing runtime failures such as "Host system is missing dependencies to run browsers".

## Verification

- Trigger `E2E Tests` workflow (PR label or `workflow_dispatch`).
- Confirm Playwright install step completes without missing dependency errors.
- Confirm `Run e2e tests` step starts browser sessions normally.
