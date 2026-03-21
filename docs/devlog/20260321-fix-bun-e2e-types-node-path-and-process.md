# Fix Bun E2E Types For process And node:path

Date: 2026-03-21

## Goal

Fix TypeScript editor/type-check errors in `e2e-test` for `process` and `node:path`.

## Changes

- Added dev dependencies in `e2e-test`:
  - `@types/node`
  - `bun-types`
- Added `e2e-test/tsconfig.json` with:
  - `module` / `moduleResolution`: `NodeNext`
  - `types`: `node`, `bun-types`
  - strict mode enabled
- Verified with `bunx tsc --noEmit` in `e2e-test`.
