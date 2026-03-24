# Use Prod-Container Seed For E2E Auth Preparation

Date: 2026-03-21

## Goal

Replace the local dev auth preparation step with a dedicated e2e seed executed inside the prod test container.

## Changes

- Reused `priv/repo/seeds/test_users.exs` as the single source of truth for the shared e2e login account.
- Simplified `e2e-test/global-setup.ts` so it only logs in and saves storage state.
- Updated e2e scripts to run the dedicated seed inside the running `vmemo` container before Playwright, so auth preparation uses the same prod environment as the app under test.
