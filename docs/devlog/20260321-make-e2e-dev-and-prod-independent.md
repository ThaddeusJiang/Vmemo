# Make E2E Dev And Prod Independent

Date: 2026-03-21

## Goal

Clarify that e2e coverage must stay independent from a single runtime mode.

## Changes

- Updated `AGENTS.md` to require the same e2e specs to work against both dev and prod-like targets.
- Refined the seed/auth preparation rule so data setup must happen in the environment currently under test, not always in a prod container.
- Updated `e2e-test/README.md` to document two supported modes:
  - dev server mode
  - local or CI prod-like mode

## Notes

- CI still runs against a prod-like Docker target.
- Local runs can target either dev or prod-like environments through `E2E_BASE_URL` and the chosen app startup method.
