# CI Visual Testing Is Source Of Truth

## Summary

Clarify that visual regression collaboration is anchored on the CI prod-like environment, not on ad-hoc local dev server runs.

## Changes

- Updated `AGENTS.md` to state that CI visual testing results are the team source of truth.
- Updated `e2e-test/README.md` to explain that local dev runs are for personal debugging only, while CI is the shared pass/fail baseline.

## Notes

- Local visual checks are still useful for iteration speed and troubleshooting.
- Snapshot updates that matter for collaboration should be verified through the CI workflow.
