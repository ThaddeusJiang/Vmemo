# Use GitHub Actions Services For E2E Dependencies

Date: 2026-03-21

## Goal

Align the e2e CI workflow with the preferred deployment shape for dependency services.

## Changes

- Updated `.github/workflows/e2e-tests.yml` to start `postgres` and `typesense` with GitHub Actions `services`.
- Changed the workflow to start the app with `docker compose -f docker-compose.yml up -d`.
- Updated `e2e-test/docker-compose.yml` so it manages only the `vmemo` service.
- Updated app runtime env values in CI to use `host.docker.internal` for PostgreSQL and Typesense service ports.
- Kept Docker Compose for app log capture, exec, and teardown.
- Updated `e2e-test/README.md` and `AGENTS.md` to document the CI convention.

## Notes

- Local e2e can still use `e2e-test/docker-compose.yml` for the app container, with external PostgreSQL and Typesense.
- CI no longer depends on Docker Compose for PostgreSQL and Typesense lifecycle management, but still uses Compose to run the app container.
