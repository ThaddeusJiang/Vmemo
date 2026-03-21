# Add Page Visual E2E Coverage

Date: 2026-03-21

## Goal

Add Playwright visual regression coverage for the main public pages, authenticated pages, and detail pages created through real UI flows.

## Changes

- Added page-level e2e specs under `e2e-test/tests/*.spec.ts` with built-in visual assertions to cover:
  - public pages with anonymous sessions
  - authenticated pages with shared storage state
  - photo detail, note detail, chat conversation, and token detail pages created through UI flows
- Updated Playwright config with default screenshot assertion settings and two visual-testing projects:
  - `iphone-se`
  - `macbook-13`
- Added `bun run e2e:update-snapshots` script and documented it in `e2e-test/README.md`.
