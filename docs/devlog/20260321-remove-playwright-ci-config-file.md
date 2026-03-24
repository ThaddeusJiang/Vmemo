# Remove Playwright CI Config File

Date: 2026-03-21

## Goal

Use a single Playwright config file and control headed/headless mode through npm scripts.

## Changes

- Updated `e2e-test/playwright.config.ts` to default `use.headless` to `true`.
- Updated `e2e-test/package.json` scripts:
  - `e2e` uses `playwright test --headed`
  - `e2e:ci` uses `playwright test --reporter=line`
- Removed `e2e-test/playwright.ci.config.ts`.
- Kept README commands aligned with the script-based mode split.
