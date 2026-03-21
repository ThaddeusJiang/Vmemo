# Decouple E2E From Temp Prod Dir

Date: 2026-03-21

## Goal

Remove the accidental dependency on the local `_prod/` directory from the committed e2e workflow.

## Changes

- Updated `test/e2e/docker-compose.yml` to be self-contained:
  - optional env file is now `test/e2e/.env`
  - PostgreSQL and Typesense use named Docker volumes instead of `_prod/_data`
- Added `test/e2e/.env.example` with the required local test env keys.
- Updated `.github/workflows/e2e-tests.yml` to start and stop `test/e2e/docker-compose.yml` directly.
- Updated `test/e2e/README.md` to document the committed e2e compose entry point.
- Updated `AGENTS.md` to forbid e2e dependencies on temporary local directories such as `_prod/`.
