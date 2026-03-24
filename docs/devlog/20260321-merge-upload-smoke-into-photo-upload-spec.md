# Merge Upload Smoke Into Photo Upload Spec

Date: 2026-03-21

## Goal

Keep upload page coverage in a single page-level e2e spec file instead of splitting the upload success flow into a separate `upload-only.spec.ts`.

## Changes

- Merged the authenticated upload smoke flow into `e2e-test/tests/photo-upload-page.spec.ts`.
- Added a shared helper for the upload success path in `e2e-test/tests/visual-helpers.ts`.
- Removed `e2e-test/tests/upload-only.spec.ts`.
