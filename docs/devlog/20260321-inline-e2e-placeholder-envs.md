# Inline E2E Placeholder Envs

Date: 2026-03-21

## Goal

Remove the redundant `e2e-test/.env.example` file for non-secret e2e placeholder values.

## Changes

- Inlined the default test-only values for `RESEND_API_KEY`, `ADMIN_TOKEN`, `SENTRY_DSN`, and `SECRET_KEY_BASE` in `e2e-test/docker-compose.yml`.
- Removed the unused `e2e-test/.env.example`.
- Updated `e2e-test/README.md` to describe the inlined placeholder env setup.
