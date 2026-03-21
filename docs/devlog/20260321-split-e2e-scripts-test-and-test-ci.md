# Split E2E Scripts Into test And test:ci

Date: 2026-03-21

## Goal

Use explicit scripts for local UI e2e and CI headless e2e without environment-variable switching logic in Playwright config.

## Changes

- Updated `test/e2e/package.json` scripts:
  - `test`: headed UI run for local human verification
  - `test:ci`: headless run for CI via dedicated Playwright config
- Simplified `test/e2e/playwright.config.ts`:
  - removed `E2E_HEADLESS` / `CI` branching logic
  - set `use.headless` to `false` (local default)
- Added `test/e2e/playwright.ci.config.ts` with `use.headless: true`.
- Updated GitHub workflow to run `bun run test:ci`.
- Updated `test/e2e/README.md` commands to use `test` / `test:ci`.
