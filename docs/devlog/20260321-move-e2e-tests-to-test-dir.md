# Move E2E Tests To e2e-test

Date: 2026-03-21

## Goal

Move Playwright TypeScript e2e tests from `others/e2e` into the `test` directory.

## Changes

- Added new e2e workspace under `e2e-test`:
  - `e2e-test/package.json`
  - `e2e-test/playwright.config.ts`
  - `e2e-test/tests/register-login.spec.ts`
  - `e2e-test/tests/upload-only.spec.ts`
  - `e2e-test/tests/login-upload.spec.ts`
- Removed old e2e test files from `others/e2e`.
- Removed legacy temporary script `others/vmemo-login-upload.spec.js`.
