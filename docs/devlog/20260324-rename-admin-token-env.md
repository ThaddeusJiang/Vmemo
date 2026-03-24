# Rename admin token env

## Summary

- Renamed the production admin environment variable from `ADMIN_TOKEN` to `ADMIN_PASSWORD`.
- Updated runtime config, deployment templates, examples, workflow envs, and active docs.
- Kept the internal application config key `:admin_token` unchanged to avoid unrelated behavior changes.

## Files

- `config/runtime.exs`
- `.env.example`
- `docker-compose.example.yml`
- `README.md`
- `others/zeabur/vmemo.yml`
- `others/zeabur/vmemo-standalone.yml`
- `.github/workflows/e2e-tests.yml`
- `docs/dev/zeabur-deploy-checklist.md`
- `docs/docker-startup-check.md`
- `docs/docker-best-practices.md`
- `docs/tasks/todo/2025-11-27-test-docker-build-and-run.md`

## Notes

- Historical devlog entries that mention `ADMIN_TOKEN` were left unchanged.
