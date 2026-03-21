# Remove Duplicate Authenticated Upload Spec

Date: 2026-03-21

## Goal

Remove duplicate e2e coverage after moving authentication into Playwright global setup.

## Changes

- Deleted `test/e2e/tests/login-upload.spec.ts` because it duplicated the authenticated upload flow.
- Kept `test/e2e/tests/upload-only.spec.ts` as the single authenticated upload smoke test.
- Removed redundant per-spec `storageState` override from `test/e2e/tests/upload-only.spec.ts` because global config already provides it.
- Updated `test/e2e/README.md` to reflect the current scripts and remaining test file.
