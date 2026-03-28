# Docker Compose Production Service Wiring

Date: 2026-03-21

## Goal

Update production compose config so `vmemo` reads environment values from `.env` and uses internal `postgres` and `typesense` services by default.

## Changes

- Added `depends_on` for `postgres` and `typesense` under `vmemo`.
- Added `env_file: .env` for `vmemo`.
- Added fallback environment values for:
  - `DATABASE_URL` -> `postgres://postgres:postgres@postgres/vmemo_dev`
  - `TYPESENSE_URL` -> `http://typesense:8108`
  - `TYPESENSE_API_KEY` -> `xyz`
- Added explicit Moondream passthrough vars:
  - `MOONDREAM_URL` -> empty by default
  - `MOONDREAM_API_KEY` -> empty by default
- Added explicit non-DB/non-Typesense runtime env declarations:
  - `OPENROUTER_API_KEY` -> empty by default
  - `PHX_SERVER` -> `true` by default
  - `ECTO_IPV6` -> `false` by default
  - `POOL_SIZE` -> `10` by default
  - `ADMIN_TOKEN` -> required at compose parse time
  - `SENTRY_DSN` -> required at compose parse time
  - `SECRET_KEY_BASE` -> required at compose parse time
  - `PHX_HOST` -> `vmemo.app` by default
  - `PORT` -> `4000` by default
  - `DNS_CLUSTER_QUERY` -> empty by default
- Added `restart: on-failure` to `vmemo` to align with other services.

## Notes

- If `.env` defines these variables, those values are used.
- If `.env` is missing DB/Typesense values, internal service defaults are used.
- Moondream variables are optional and only applied when provided.
