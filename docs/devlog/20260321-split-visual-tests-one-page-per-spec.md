# Split Visual Tests One Page Per Spec

Date: 2026-03-21

## Goal

Align Playwright visual testing structure with the project rule that each page should have its own spec file instead of being generated from a route array in a single file.

## Changes

- Replaced `e2e-test/tests/page-visual.spec.ts` with one page per `*.spec.ts` file.
- Added `e2e-test/tests/visual-helpers.ts` for shared visual-testing helpers and real UI setup flows.
- Updated `.github/workflows/e2e-tests.yml`, `AGENTS.md`, and `e2e-test/README.md` to use the one-page-per-spec structure.
