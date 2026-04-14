# GitHub Release

This guide describes how maintainers create a new GitHub release for Vmemo.

## 1) Prepare

- Ensure target branch is up to date (`main` by default).
- Ensure CI is green.
- Ensure release notes are ready.

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
3. Write release title and notes
4. Publish release

## 4) Post-release Checks

- Verify release page is public and complete.
- Verify downstream Docker publish workflow is triggered (if configured).
- Record rollback target (previous stable tag).
