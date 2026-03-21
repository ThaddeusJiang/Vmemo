# Simplify Workflow Dispatch Checkbox

Date: 2026-03-21

## Goal

Reduce manual CI inputs to the minimum needed so workflow dispatch only exposes one checkbox for snapshot updates.

## Changes

- Updated `.github/workflows/e2e-tests.yml` so manual `workflow_dispatch` always runs smoke e2e and visual testing.
- Kept only one manual input: `update_snapshots`.
- Updated `AGENTS.md` and `e2e-test/README.md` to document the simplified manual trigger behavior.
