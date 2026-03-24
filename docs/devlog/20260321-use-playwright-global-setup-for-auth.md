# Use Playwright Global Setup For Auth

Date: 2026-03-21

## Goal

Remove duplicated login logic from individual e2e specs and prepare authenticated state through a single Playwright setup flow.

## Changes

- Added `e2e-test/global-setup.ts` to:
  - register the shared e2e account when needed
  - log in once
  - save authenticated storage state to `/tmp/vmemo-e2e-storage.json`
- Updated `e2e-test/playwright.config.ts` to use `globalSetup` and a shared `storageState`.
- Simplified `e2e-test/tests/login-upload.spec.ts` so it starts from an authenticated session instead of embedding auth logic.
- Removed `e2e-test/tests/register-login.spec.ts` because its responsibility moved into global setup.
- Updated `e2e-test/README.md` and `AGENTS.md` to document the shared-auth testing pattern.
