---
name: "release"
description: "Prepare and execute a Vmemo release with explicit config-change confirmation gates."
---

# Release

Use this skill when the user asks to create/publish a release tag or GitHub release.

## Goal

Ship a release safely while making config changes explicit before publish.

## Scope

- This skill focuses on release readiness, versioning, and release execution.
- If release includes config changes, you must pause and get explicit user confirmation before continuing.

## Required workflow

1. Preflight checks
2. Resolve release version
3. Detect and review config changes (mandatory gate)
4. Prepare release notes and confirm with user
5. Execute release (tag + GitHub release)
6. Post-release verification summary

## Step 1: Preflight checks

Run:

```bash
git rev-parse --abbrev-ref HEAD
git status --porcelain
```

Guardrails:

- Prefer releasing from `main` or `develop` (current repo may use either in docs/workflows).
- If working tree is dirty, list changed files and ask whether to proceed.

## Step 2: Resolve release version

Use script:

```bash
mix run --no-start .codex/skills/release/scripts/resolve_release_version.exs [VERSION]
```

Rules:

- If `VERSION` is provided, validate format `YYYY.M.Patch` (month `1..12`, patch `>=1`, no leading zero).
- If omitted, default to `Asia/Tokyo` current date in `YYYY.M.D` and show it to user.

## Step 3: Detect config changes (mandatory gate)

Use script:

```bash
mix run --no-start .codex/skills/release/scripts/check_config_changes.exs [BASE_REF] [TARGET_REF]
```

Defaults:

- `BASE_REF`: latest release tag matching CalVer; fallback `origin/develop`, then `origin/main`.
- `TARGET_REF`: `HEAD`.

Required behavior:

- If script reports config/env changes, stop and present the report.
- Ask for explicit confirmation to proceed with release despite config changes.
- Do not continue until user confirms.

## Step 4: Release notes

- Generate or collect release notes for the resolved version.
- Show notes to user and wait for explicit confirmation.
- If edits requested, update notes first.

## Step 5: Execute release

Use the unified release path: tag first, then create/publish release in GitHub UI.

Typical commands:

```bash
git tag -a <VERSION> -m "release: <VERSION>"
git push origin <VERSION>
```

## Step 6: Final report

Return:

- Release version
- Base ref used for config diff
- Whether config changes were detected and confirmed
- Tag / GitHub release URL (if available)
- Manual verification checklist (release page completeness, downstream workflow trigger, rollback target)

## Guardrails

- Never skip config-change detection.
- Never hide config/env changes in summary.
- Never claim release published if only tag push is done.
- If required tools (`git`, `gh`, `mix`) are missing, report and stop.
