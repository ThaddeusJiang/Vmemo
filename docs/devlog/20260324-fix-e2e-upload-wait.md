# 2026-03-24 Fix e2e upload wait

## Background

GitHub Actions run `23414457237` failed in job `68107293145` on the upload-related Playwright specs.

The failing tests clicked `Upload` and then navigated to `/photos` immediately. In CI, that could interrupt the LiveView upload flow before the `save` event finished.

## Findings

- Playwright failures came from `createUploadedPhoto` and `uploadPhotoAndAssertSuccess`
- The app logs showed `PhotosIndexLive` still reading only the single seeded photo
- That indicates the new photo was not persisted yet, instead of only being delayed by Typesense sync

## Change

- Wait for the success toast `Photos uploaded successfully` before leaving the upload page
- Extend the follow-up polling window from 20 seconds to 30 seconds to keep CI tolerant to slower containers

## Result

The upload assertions now wait for the user-visible completion signal before verifying the photo list.
