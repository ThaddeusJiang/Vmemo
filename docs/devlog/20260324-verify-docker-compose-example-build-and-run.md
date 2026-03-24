# 2026-03-24 Verify docker compose example build and run

## Goal

Validate whether `docker-compose.example.yml` is complete and can successfully build and run the application stack.

## Plan

- inspect the compose file, Dockerfile, runtime config, and required environment variables
- run Docker Compose validation and real container build/start checks
- fix gaps in the compose example if the stack cannot boot cleanly
- re-run the verification after changes

## Findings

- `docker compose -f docker-compose.example.yml build vmemo` completed successfully.
- the original compose file could start the core services, but `vmemo` restarted several times because `depends_on` only waited for the `postgres` and `typesense` containers to start, not for them to become ready
- the original compose file also treated `cloudflared` as part of the default stack, which made the example require preview tunnel credentials even for a local-only boot path

## Changes

- added healthchecks for `postgres` and `typesense`
- changed `vmemo` to wait for healthy dependencies before starting
- gave `MOONDREAM_URL` a concrete default value in the compose example
- switched the default `PHX_HOST` to `localhost` for local runs
- moved `cloudflared` behind a `preview` profile so the default stack stays local-first
- added `TUNNEL_TOKEN` to `.env.example`

## Verification

- `docker compose -f docker-compose.example.yml config`
- `docker compose -f docker-compose.example.yml build vmemo`
- `docker compose -f docker-compose.example.yml up -d postgres typesense vmemo`
- `curl -I http://127.0.0.1:14000`
- `docker compose -f docker-compose.example.yml --profile preview up -d cloudflared`

## Result

- the default stack now builds and runs cleanly for local access on `http://127.0.0.1:14000`
- the preview tunnel is still available, but only when the `preview` profile is explicitly enabled
