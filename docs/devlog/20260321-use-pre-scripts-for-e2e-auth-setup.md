# Use Pre Scripts For E2E Auth Setup

Date: 2026-03-21

## Goal

Remove duplicated auth preparation chaining in e2e npm scripts.

## Changes

- Updated `e2e-test/package.json` scripts to use lifecycle hooks:
  - `pree2e` runs `prepare-auth` before `e2e`
  - `pree2e:ci` runs `prepare-auth` before `e2e:ci`
- Simplified `e2e` and `e2e:ci` commands to only run Playwright.
