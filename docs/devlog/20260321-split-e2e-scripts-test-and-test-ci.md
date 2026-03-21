# Split E2E Scripts Into test And test:ci

Date: 2026-03-21

## Goal

Use explicit scripts for local UI e2e and CI headless e2e without environment-variable switching logic in Playwright config.

## Changes

- Updated `e2e-test/package.json` scripts:
  - `test`: headed UI run for local human verification
  - `test:ci`: headless run for CI via dedicated Playwright config
- Simplified `e2e-test/playwright.config.ts`:
  - removed `E2E_HEADLESS` / `CI` branching logic
  - set `use.headless` to `false` (local default)
- Added `e2e-test/playwright.ci.config.ts` with `use.headless: true`.
- Updated GitHub workflow to run `bun run test:ci`.
- Updated `e2e-test/README.md` commands to use `test` / `test:ci`.
