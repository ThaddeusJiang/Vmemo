# Move Ash migrations into repo directory

## Background

- We standardized repo naming to `Vmemo.Repo`.
- Historical Ash migrations were still in `priv/ash_repo/migrations`.
- Release migration had to carry compatibility logic for both `repo` and `ash_repo`.

## Changes

- Moved all migration files from `priv/ash_repo/migrations` to `priv/repo/migrations`.
- Removed the temporary legacy migration directory mapping in `Vmemo.Release`.
- Kept release migration behavior aligned with standard repo path derivation.

## Result

- Migration files now live in one place: `priv/repo/migrations`.
- Release migration no longer depends on legacy directory compatibility code.
