# Move E2E Directory To e2e-test

Date: 2026-03-21

## Goal

Rename the e2e workspace directory from `test/e2e` to `e2e-test` and keep all project references consistent.

## Changes

- Moved directory: `test/e2e` -> `e2e-test`.
- Updated workflow paths in `.github/workflows/e2e-tests.yml`:
  - default working directory
  - artifact paths
- Updated e2e README and devlog references from `test/e2e` to `e2e-test`.
- Updated `.gitignore` e2e ignore entries to the new directory name.
- Performed repository-wide search to ensure no remaining `test/e2e` references.
