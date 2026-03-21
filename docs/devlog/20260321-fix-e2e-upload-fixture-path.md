# Fix E2E Upload Fixture Path

Date: 2026-03-21

## Goal

Remove machine-specific absolute file paths from Playwright upload tests.

## Changes

- Added `e2e-test/fixtures/upload-files/test-red-image.png` as a test-local upload fixture copied from `test/testdata_files/`
- Updated `e2e-test/tests/upload-only.spec.ts` to resolve the upload file relative to the spec directory
- Documented the fixture location in `e2e-test/README.md`
