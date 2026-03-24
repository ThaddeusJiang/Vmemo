# Restore docker entrypoint migrations

## Summary

- Restored `ENTRYPOINT` for Docker startup.
- Moved `mix ash.migrate` and `mix ts.migrate` into `rel/entrypoint.sh`.
- Kept `CMD` as `mix phx.server` so the main process stays explicit and overridable.

## Files

- `Dockerfile`
- `rel/entrypoint.sh`
- `README.md`
- `docs/build_and_run.md`
- `docs/docker-startup-check.md`
- `docs/docker-best-practices.md`
- `docs/dev/zeabur-deploy-checklist.md`
