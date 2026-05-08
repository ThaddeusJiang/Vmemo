# Release

This guide is the canonical release playbook for Vmemo maintainers.

It covers the full workflow:

- version update and scope freeze
- pre-release checks
- tag and release publish
- post-release verification and rollback preparation

## 1) Pre-release Preparation

- Confirm release scope (features, fixes, known risks).
- Ensure target branch is `main` and up to date.
- Ensure required CI is green.
- Ensure release notes are prepared and reviewed.

Commands:

```bash
git checkout main
git pull --ff-only
```

## 2) Resolve Release Version

Use CalVer: `YYYY.M.Patch` (example: `2026.4.19`).

Recommended command:

```bash
mix run --no-start .agents/skills/release/scripts/resolve_release_version.exs [VERSION]
```

Rules:

- If no version is provided, script defaults to Tokyo date.
- If the same day needs another release, increase `Patch` (`2026.4.19` -> `2026.4.20` etc.).

## 3) Config Change Gate (Mandatory)

Before publishing, detect config/env changes and explicitly confirm impact.

```bash
mix run --no-start .agents/skills/release/scripts/check_config_changes.exs [BASE_REF] [TARGET_REF]
```

Required behavior:

- If config/env changes are detected, stop and review the report.
- Confirm required env keys, rollout plan, and rollback impact.
- Do not proceed until explicit confirmation is made.

## 4) Release Notes Finalization

- Prepare final release title and notes (user-facing summary + important technical changes).
- Include breaking changes and migration/operation notes when applicable.
- Do not rely only on auto-generated notes.

## 5) Publish (Tag + GitHub Release)

Create and push the tag:

```bash
git tag -a <VERSION> -m "release: <VERSION>"
git push origin <VERSION>
```

Publish on GitHub:

1. Open `Releases` -> `Draft a new release`.
2. Select tag `<VERSION>`.
3. Fill release title and final release notes.
4. Publish release.

## 6) Post-release Verification

- Verify release page is public and complete.
- Verify Docker publish workflow was triggered and completed.
- Pull and run released image in a smoke environment if needed.
- Record rollback target (previous stable tag).

Suggested checks:

- app startup and migration path
- login / upload / search / API token core flows
- error monitoring baseline (Sentry, queue backlog)

## 7) Rollback Readiness

- Keep previous stable image/tag available.
- Document rollback steps for current release.
- Identify non-reversible migration/config changes.

## Quick Checklist

- [ ] Branch: `main` up to date
- [ ] CI green
- [ ] Version resolved (`YYYY.M.Patch`)
- [ ] Config gate passed (or explicitly approved)
- [ ] Release notes reviewed
- [ ] Tag created and pushed
- [ ] GitHub release published
- [ ] Post-release verification done
- [ ] Rollback target recorded
