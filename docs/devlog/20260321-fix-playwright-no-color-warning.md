# Fix Playwright NO_COLOR warning

## Summary

- Updated Playwright package scripts to unset `NO_COLOR` before invoking `playwright test`.
- This avoids Node printing the warning that `NO_COLOR` is ignored when `FORCE_COLOR` is present during `bun run`.

## Verification

- Run `bun run e2e:ci --help` from `e2e-test` and confirm the warning no longer appears.
