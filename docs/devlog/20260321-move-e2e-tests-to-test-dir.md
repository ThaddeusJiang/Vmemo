# Move E2E Tests To test/e2e

Date: 2026-03-21

## Goal

Move Playwright TypeScript e2e tests from `others/e2e` into the `test` directory.

## Changes

- Added new e2e workspace under `test/e2e`:
  - `test/e2e/package.json`
  - `test/e2e/playwright.config.ts`
  - `test/e2e/tests/register-login.spec.ts`
  - `test/e2e/tests/upload-only.spec.ts`
  - `test/e2e/tests/login-upload.spec.ts`
- Removed old e2e test files from `others/e2e`.
- Removed legacy temporary script `others/vmemo-login-upload.spec.js`.
