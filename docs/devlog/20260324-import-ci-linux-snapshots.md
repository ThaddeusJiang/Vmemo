# 2026-03-24 Import CI Linux snapshots

## Background

GitHub Actions run `23475212204` failed in job `68306452258` because the prod-like Linux visual baselines used in CI were not present in git.

The artifact uploaded by that run already contained the generated `*-linux.png` snapshots under `e2e-test/tests/**-snapshots/`.

## Findings

- PR e2e compared against Linux snapshots, not local Darwin snapshots
- The runner artifact contained the full Linux baseline set for the current branch
- Several pages failed visual comparison because the Linux baselines were missing or outdated in the repository

## Change

- Import the Linux snapshot files from the CI artifact into `e2e-test/tests/**-snapshots/`
- Keep the existing Darwin snapshots for local development

## Result

The repository now includes the prod-like Linux Playwright baselines required by CI visual comparisons.
