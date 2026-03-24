# 2026-03-24 Fix e2e update snapshots mutual exclusion

## Background

The e2e workflow started running `update snapshots`, committing the new baselines, and then still running the normal visual comparison step in the same CI run.

That defeats the purpose of snapshot update mode because a run that updates baselines should not immediately re-check visual diffs in the same job.

## Findings

- The `if` guards for `Update e2e snapshots`, `Commit updated snapshots`, and `Run e2e tests` had been commented out
- The workflow file also referenced non-existent action version tags for checkout, upload-artifact, and add-and-commit

## Change

- Restore the `if` guards so snapshot update mode and normal e2e mode are mutually exclusive
- Switch actions back to known valid versions:
  - `actions/checkout@v4`
  - `oven-sh/setup-bun@v2`
  - `EndBug/add-and-commit@v9`
  - `actions/upload-artifact@v4`

## Result

Manual snapshot update runs now stop after updating and committing baselines, while PR e2e runs continue to perform normal visual regression checks.
