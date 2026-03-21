# Use Playwright Global Setup For Auth

Date: 2026-03-21

## Goal

Remove duplicated login logic from individual e2e specs and prepare authenticated state through a single Playwright setup flow.

## Changes

- Added `test/e2e/global-setup.ts` to:
  - register the shared e2e account when needed
  - log in once
  - save authenticated storage state to `/tmp/vmemo-e2e-storage.json`
- Updated `test/e2e/playwright.config.ts` to use `globalSetup` and a shared `storageState`.
- Simplified `test/e2e/tests/login-upload.spec.ts` so it starts from an authenticated session instead of embedding auth logic.
- Removed `test/e2e/tests/register-login.spec.ts` because its responsibility moved into global setup.
- Updated `test/e2e/README.md` and `AGENTS.md` to document the shared-auth testing pattern.
