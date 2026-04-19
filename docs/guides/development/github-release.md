# GitHub Release

This guide describes the unified Vmemo release path: use release skill/scripts, then publish on GitHub.

## 1) Prepare

- Ensure target branch is up to date (`main`).
- Ensure CI is green.
- Resolve release version and prepare release notes.
- Run config-change gate and get explicit confirmation if config/env changes are detected.

Recommended commands:

```bash
mix run --no-start .codex/skills/release/scripts/resolve_release_version.exs [VERSION]
mix run --no-start .codex/skills/release/scripts/check_config_changes.exs [BASE_REF] [TARGET_REF]
```

## 2) Create Version Tag

Use a calendar-like version for consistency, for example `2026.4.14`.

```bash
git checkout main
git pull --ff-only
git tag -a 2026.4.14 -m "release: 2026.4.14"
git push origin 2026.4.14
```

## 3) Create GitHub Release

On GitHub:

1. Open Releases -> Draft a new release
2. Select tag `2026.4.14`
3. Write/review release title and notes (do not rely on auto-generated notes alone)
4. Publish release

## 4) Post-release Checks

- Verify release page is public and complete.
- Verify downstream Docker publish workflow is triggered (if configured).
- Record rollback target (previous stable tag).
