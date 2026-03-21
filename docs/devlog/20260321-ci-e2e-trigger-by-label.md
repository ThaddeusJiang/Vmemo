# CI E2E Trigger By Label

Date: 2026-03-21

## Goal

Add a CI workflow that runs e2e tests only when PR is marked with a specific label.

## Changes

- Added `.github/workflows/e2e-tests.yml`.
- Workflow trigger:
  - `pull_request` events: `labeled`, `synchronize`, `reopened`
  - job-level condition requires label `run-e2e-testing`
- Workflow pipeline:
  - build application Docker image from current branch code
  - start app stack via `_prod/docker-compose.yml`
  - run Playwright e2e tests in `test/e2e` via Bun
  - upload screenshots and Phoenix logs as artifacts
