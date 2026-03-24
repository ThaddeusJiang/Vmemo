# 2026-03-24 Remove unused docker entrypoint

## Summary

Removed the unused duplicate Docker entrypoint script and aligned docs with the actual runtime entrypoint.

## Changes

- deleted `docker/entrypoint.sh` because the Docker image uses `rel/entrypoint.sh`
- updated the Zeabur deployment checklist to reference `rel/entrypoint.sh`

## Files

- `docker/entrypoint.sh`
- `docs/dev/zeabur-deploy-checklist.md`
