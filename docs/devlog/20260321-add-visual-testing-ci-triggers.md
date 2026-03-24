# Add Visual Testing CI Triggers

Date: 2026-03-21

## Goal

Allow Playwright visual testing to run in CI from both PR labels and manual workflow dispatch, with an explicit checkbox to update visual snapshots when needed.

## Changes

- Updated `.github/workflows/e2e-tests.yml` to support:
  - PR label `run-e2e-testing` for both smoke e2e and visual testing
  - manual `workflow_dispatch` with a single `update_snapshots` checkbox
- Added a dedicated CI path for running `tests/page-visual.spec.ts`.
- Uploaded visual snapshot directories as workflow artifacts so manual snapshot updates can be downloaded and reviewed.
