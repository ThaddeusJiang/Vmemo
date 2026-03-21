# Inline E2E Placeholder Envs

Date: 2026-03-21

## Goal

Remove the redundant `test/e2e/.env.example` file for non-secret e2e placeholder values.

## Changes

- Inlined the default test-only values for `RESEND_API_KEY`, `ADMIN_TOKEN`, `SENTRY_DSN`, and `SECRET_KEY_BASE` in `test/e2e/docker-compose.yml`.
- Removed the unused `test/e2e/.env.example`.
- Updated `test/e2e/README.md` to describe the inlined placeholder env setup.
