# _prod Docker Compose ARM Compatibility

Date: 2026-03-21

## Goal

Make production compose config runnable from `_prod/` on Apple Silicon and reduce setup friction.

## Changes

- Updated `_prod/docker-compose.prod.yml`:
  - Added `platform: ${VMEMO_PLATFORM:-linux/amd64}` for `vmemo`.
  - Made `.env` optional via:
    - `env_file:`
    - `  - path: .env`
    - `    required: false`
  - Added required `RESEND_API_KEY` to `vmemo` environment.
  - Fixed postgres init script path to `../docker/postgres/initdb`.
- Added `_prod/.env.example` with required keys and optional defaults.
- Updated root `docker-compose.prod.yml` to match:
  - Added `VMEMO_PLATFORM` support for `vmemo`.
  - Made `.env` optional.
  - Added required `RESEND_API_KEY` for runtime parity.
  - Removed `PHX_HOST` hardcoded environment injection so host is configured via `.env`.

## Validation

- `docker compose -f _prod/docker-compose.prod.yml config` passes with required env vars.
- `docker compose up -d` reaches container creation.
- Remaining startup failure is host port conflict (`8766`/`54321` already in use), not compose definition issues.

## Follow-up

- Encountered runtime `500` with:
  - `cookie store expects conn.secret_key_base to be at least 64 bytes`
- Root cause: temporary short `SECRET_KEY_BASE` passed via shell env.
- Fix:
  - moved required runtime vars into `_prod/.env` (`ADMIN_TOKEN`, `SENTRY_DSN`, `SECRET_KEY_BASE`, `RESEND_API_KEY`)
  - generated a 64+ bytes secret using `mix phx.gen.secret`
  - restarted compose from `_prod` without shell overrides
- Verified:
  - container env includes `PHX_HOST=vmemo.prod.orb.local`
  - vmemo starts cleanly without the previous cookie secret error

## Browser Check

- Added `ports: ["4000:4000"]` for `_prod` `vmemo` service to enable host-side browser checks.
- Installed Playwright Chromium and captured screenshot:
  - URL: `http://127.0.0.1:4000`
  - Screenshot: `/tmp/vmemo-prod-home.png`
- Result: landing page renders successfully in browser automation.

## Origin Issue Fix

- Removed the temporary `PHX_CHECK_ORIGIN` runtime customization.
- Fixed LiveView socket origin mismatch by aligning `_prod/.env` `PHX_HOST` with actual local access host:
  - `PHX_HOST=localhost`
- Re-verified with Playwright at `http://localhost:4000`:
  - screenshot: `/tmp/vmemo-prod-home-localhost.png`
  - logs show LiveView socket connected without `Could not check origin` errors.

## Develop Image A/B Test

- Switched `_prod/docker-compose.yml` `vmemo` image to `thaddeusjiang/vmemo:develop` and ran integration startup test.
- Result:
  - containers start (`postgres`, `typesense`, `vmemo`) but app is not reachable (`curl` empty reply).
  - vmemo logs show Erlang kernel boot failure (`failed_to_start_child,user,nouser`, `user_drv`, `erlang:nif_error/1`).
- A/B check:
  - bypassed image entrypoint and ran `mix phx.server` directly (`entrypoint: []`, `command: ["mix", "phx.server"]`).
  - same crash persists, so it is not caused by entrypoint migration loop.
- Platform check:
  - `vmemo:develop` does not provide `linux/arm64` manifest.
  - currently only `linux/amd64` path is available and it still crashes in this environment.
