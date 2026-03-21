# Update Testing Guidelines For User-Centric E2E

Date: 2026-03-21

## Goal

Persist explicit user-centric e2e testing rules in `AGENTS.md`.

## Changes

- Added a dedicated `e2e testing guidelines (user perspective)` section under local testing conventions.
- Clarified that tests should click visible button labels (for example `Login`) instead of implementation-detail selectors like `button[type='submit']`.
- Added selector priority guidance:
  - visible text / ARIA role
  - label
  - test id
  - CSS implementation detail (last resort)
