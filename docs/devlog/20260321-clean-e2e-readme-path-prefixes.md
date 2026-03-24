# Clean E2E README Path Prefixes

Date: 2026-03-21

## Goal

Align `e2e-test/README.md` commands and paths with the current workflow and reduce repeated `e2e-test` prefixes.

## Changes

- Unified command examples to run from the `e2e-test` directory.
- Updated compose command examples to use `docker-compose.yml` from current directory.
- Updated artifact path from `e2e-test/test-results/` to `test-results/`.
- Clarified CI note to match the workflow behavior.
