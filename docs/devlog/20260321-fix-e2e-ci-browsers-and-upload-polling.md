# Fix E2E CI Browsers And Upload Polling

## Summary

Fix the next layer of CI e2e failures after the Typesense service issue: missing Playwright browser installation for the mobile project and a flaky upload success assertion in the prod-like CI environment.

## Changes

- Updated `.github/workflows/e2e-tests.yml` to install both `chromium` and `webkit`.
- Updated `e2e-test/tests/visual-helpers.ts` so uploaded photo assertions re-open `/photos` while polling instead of checking a stale DOM snapshot.

## Reason

- The `iPhone SE` Playwright project requires `webkit` in CI.
- The upload flow succeeded in CI, but the photo list assertion polled against a page state that was loaded too early and never refreshed.
