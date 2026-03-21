# Move E2E Prepare Auth To CI Workflow

Date: 2026-03-21

## Goal

Keep local e2e scripts focused on running tests, and run CI-only auth preparation directly in the CI workflow.

## Changes

- Removed `prepare-auth`, `pree2e`, and `pree2e:ci` from `test/e2e/package.json`.
- Kept local e2e scripts as direct Playwright commands:
  - `e2e`
  - `e2e:ci`
- Added a dedicated `Prepare e2e auth user` step in `.github/workflows/e2e-tests.yml`:
  - runs seed inside the running `vmemo` container
  - uses `unset PHX_SERVER && mix run priv/repo/seeds/test_users.exs`
- Updated `test/e2e/README.md` and `AGENTS.md` to reflect this workflow split.
