# Unify E2E And Visual Label Trigger

Date: 2026-03-21

## Goal

Use a single PR label for CI-triggered e2e coverage so visual testing is included automatically when `run-e2e-testing` is applied.

## Changes

- Updated `.github/workflows/e2e-tests.yml` so both smoke e2e and visual testing run from the same PR label: `run-e2e-testing`.
- Kept manual `workflow_dispatch` checkbox inputs for smoke e2e, visual testing, and snapshot updates.
- Updated `e2e-test/README.md` to remove the separate `run-visual-testing` label description.
