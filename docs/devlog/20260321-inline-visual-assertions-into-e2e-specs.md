# Inline Visual Assertions Into E2E Specs

Date: 2026-03-21

## Goal

Stop treating visual testing as a separate Playwright suite and instead execute screenshot snapshot assertions inside the normal page-level e2e specs.

## Changes

- Renamed page snapshot tests to standard `*.spec.ts` files.
- Merged the authenticated upload smoke test into `photo-upload-page.spec.ts` instead of keeping a separate upload-only spec.
- Updated CI to run a single e2e job; normal runs verify snapshots and manual `update_snapshots` runs update them.
- Updated `AGENTS.md` and `e2e-test/README.md` to define visual assertions as part of regular e2e tests instead of a separate testing layer.
