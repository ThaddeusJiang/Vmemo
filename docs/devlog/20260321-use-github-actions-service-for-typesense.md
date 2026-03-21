# 20260321-use-github-actions-service-for-typesense

## Summary
- Replace the CI Typesense `docker run` step with a GitHub Actions `services` container.

## Changes
- Added a `typesense` service to `.github/workflows/elixir-test.yml` using `typesense/typesense:27.1`.
- Moved Typesense runtime configuration from CLI flags to environment variables:
  `TYPESENSE_DATA_DIR=/data` and `TYPESENSE_API_KEY=xyz`.
- Kept the explicit Typesense readiness check with `curl -fsS http://localhost:8108/health`.
- Preserved the in-memory data mount via `--tmpfs /data:rw,size=512m` in the service `options`.

## Notes
- This change relies on Typesense's documented mapping from CLI flags to `TYPESENSE_*` environment variables.
- Verification was not run in this change.
