# 2026-03-24 Auto commit e2e snapshots

## Background

The manual `workflow_dispatch` path for e2e visual testing updated Playwright snapshots inside CI, but only uploaded them as artifacts.

That is not enough for long-term visual regression checks because baseline snapshots must live in git.

## Findings

- The workflow had `update_snapshots` enabled without any git write-back step
- `GITHUB_TOKEN` only had read access, so CI could not push snapshot updates
- The update-snapshots step and the normal e2e step were not mutually exclusive

## Change

- Grant `contents: write` permission to the workflow
- Make `Update e2e snapshots` run only for manual dispatch with `update_snapshots=true`
- Add a step that stages `*-snapshots`, commits them, and pushes them back to the selected branch
- Keep normal e2e runs unchanged for PR label triggers and manual dispatch without snapshot updates

## Result

Snapshot update runs now persist the new Playwright baselines to git instead of leaving them only in workflow artifacts.
