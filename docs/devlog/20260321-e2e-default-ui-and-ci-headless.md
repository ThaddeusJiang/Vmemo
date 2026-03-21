# Set E2E Default To UI And CI To Headless

Date: 2026-03-21

## Goal

Make local e2e tests run in visible browser mode by default for human verification, while keeping CI execution headless.

## Changes

- Renamed npm script from `test:e2e` to `e2e` in `e2e-test/package.json`.
- Updated Playwright config to:
  - default to headed mode locally
  - default to headless mode when `CI=true`
  - allow explicit override by `E2E_HEADLESS=true|false`
- Updated GitHub Actions workflow to run e2e with `E2E_HEADLESS=true`.
- Updated `e2e-test/README.md` command examples to use `bun run e2e`.
- Updated `AGENTS.md` to document the local headed / CI headless rule.
