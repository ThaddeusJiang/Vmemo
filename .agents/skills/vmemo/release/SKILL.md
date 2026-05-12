---
name: "vmemo-release-skill"
description: "Prepare a Vmemo release PR with explicit config-change confirmation gates."
---

# Release

Use this skill when the user asks to prepare a release PR for version bump.

## Goal

Prepare a release PR safely while making config changes explicit before merge.

## Scope

- This skill focuses on release readiness, versioning, and release PR creation.
- If release includes config changes, you must pause and get explicit user confirmation before continuing.

## Required workflow

1. Preflight checks
2. Resolve release version
3. Detect and review config changes (mandatory gate)
4. Update `mix.exs` version
5. Open a release PR to `main`
6. Post-release-PR summary

## Step 1: Preflight checks

Run:

```bash
git rev-parse --abbrev-ref HEAD
git status --porcelain
```

Guardrails:

- Prefer releasing from `main`.
- If working tree is dirty, list changed files and ask whether to proceed.

## Step 2: Resolve release version

Use script:

```bash
mix run --no-start .agents/skills/vmemo/release/scripts/resolve_release_version.exs [VERSION]
```

Rules:

- If `VERSION` is provided, validate format `YYYY.M.Patch` (month `1..12`, patch `>=1`, no leading zero).
- If omitted, default to `Asia/Tokyo` current date in `YYYY.M.D` and show it to user.

## Step 3: Detect config changes (mandatory gate)

Use script:

```bash
mix run --no-start .agents/skills/vmemo/release/scripts/check_config_changes.exs [BASE_REF] [TARGET_REF]
```

Defaults:

- `BASE_REF`: latest release tag matching CalVer; fallback `origin/main`, then `origin/master`.
- `TARGET_REF`: `HEAD`.

Required behavior:

- If script reports config/env changes, stop and present the report.
- Ask for explicit confirmation to proceed with release despite config changes.
- Do not continue until user confirms.

## Step 4: Update `mix.exs` version

- Update `mix.exs` project version to the resolved release version.
- Keep change focused: only update `project/0` `version` field.
- Show the diff and require explicit user confirmation before creating PR.

Example check:

```bash
rg -n 'version:\s*"' mix.exs
git diff -- mix.exs
```

## Step 5: Open a release PR to `main`

- After updating `mix.exs` version, create a dedicated release PR targeting `main`.
- The release workflow ends at PR creation and waits for merge.
- If current branch is not release-dedicated, create one first (for example `release/<VERSION>`).
- PR title/body should follow repository conventions and clearly state this is the release PR for `<VERSION>`.

Typical commands:

```bash
git switch -c release/<VERSION>
git add mix.exs
git commit -m "chore(release): bump version to <VERSION>"
git push -u origin release/<VERSION>
gh pr create --base main --title "chore(release): <VERSION>" --body-file <PR_BODY_FILE>
```

Required behavior:

- Do not tag or publish GitHub release in this skill flow.
- GitHub release is handled by CI after release PR merge.

## Step 6: Final report

Return:

- Release version
- Whether `mix.exs` version was updated to `<VERSION>`
- Release PR URL (target: `main`) and merge status
- Base ref used for config diff
- Whether config changes were detected and confirmed
- Note that GitHub release will be created by action after PR merge

## Guardrails

- Never skip config-change detection.
- Never hide config/env changes in summary.
- Never skip updating `mix.exs` version when running this release workflow.
- Never skip the release PR to `main` after version bump.
- Never tag/release directly in this workflow.
- If required tools (`git`, `gh`, `mix`) are missing, report and stop.
