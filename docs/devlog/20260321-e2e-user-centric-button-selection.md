# E2E User-Centric Button Selection

Date: 2026-03-21

## Goal

Make e2e interaction closer to real user behavior and avoid implementation-detail selectors.

## Changes

- Updated Playwright e2e tests:
  - replaced submit-button selectors like `button[type='submit']`
  - now click visible button labels via role queries (`Login`, `Register`, `Upload`)
- Updated `AGENTS.md` to require user-centric UI interactions in e2e tests.
