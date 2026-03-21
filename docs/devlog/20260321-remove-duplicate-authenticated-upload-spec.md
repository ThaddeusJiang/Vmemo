# Remove Duplicate Authenticated Upload Spec

Date: 2026-03-21

## Goal

Remove duplicate e2e coverage after moving authentication into Playwright global setup.

## Changes

- Deleted `e2e-test/tests/login-upload.spec.ts` because it duplicated the authenticated upload flow.
- Kept `e2e-test/tests/upload-only.spec.ts` as the single authenticated upload smoke test.
- Removed redundant per-spec `storageState` override from `e2e-test/tests/upload-only.spec.ts` because global config already provides it.
- Updated `e2e-test/README.md` to reflect the current scripts and remaining test file.
