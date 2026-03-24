# Local Build Develop Image Test

Date: 2026-03-21

## Goal

Validate `_prod/docker-compose.yml` with a locally built `thaddeusjiang/vmemo:develop` image.

## Changes

- Updated `Dockerfile` runner dependencies:
  - replaced `libncurses5` with `libncurses6 libtinfo6` for Debian trixie compatibility.
- Updated `_prod` runtime platform for local build test:
  - `_prod/.env`: `VMEMO_PLATFORM=linux/arm64`
- Restored `_prod/docker-compose.yml` vmemo startup to image defaults:
  - removed temporary A/B overrides (`entrypoint: []`, `command: ["mix", "phx.server"]`).

## Build & Run

- Built local image:
  - `docker build -t thaddeusjiang/vmemo:develop .`
- Started compose with local image only:
  - `docker compose -f _prod/docker-compose.yml up -d --force-recreate --pull never`

## Verification

- Container image in use:
  - `prod-vmemo-1` uses local image id `sha256:cab301e05925...`
- Service startup:
  - migrations run successfully
  - endpoint started at `:::4000`
- HTTP check:
  - `GET http://localhost:4000/` returns `200 OK`
- Browser check:
  - Playwright screenshot: `/tmp/vmemo-develop-local-home.png`
  - page renders successfully.
