# Docker multi-arch release for macOS hosts

Date: 2026-03-21

## Goal

Make published Vmemo images usable on both Linux hosts and macOS Docker Desktop without forcing amd64 emulation.

## Changes

- Updated `.github/workflows/docker-publish.yml` to always publish `linux/amd64` and `linux/arm64/v8`.
- Removed the special-case downgrade that published `develop` as amd64-only.
- Simplified publishing to a single `docker/build-push-action` step that pushes the final tags directly:
  - branch pushes publish `<branch>`
  - `main` also publishes `latest`
  - tag pushes publish the tag name
- Updated `README-dockerhub.md` wording to clarify that macOS support comes from Linux multi-arch images runnable via Docker Desktop, not from a separate `macos/*` container image platform.

## Validation

- Checked current Docker Hub manifests before the change:
  - `thaddeusjiang/vmemo:develop` exposed `linux/amd64` only
  - `thaddeusjiang/vmemo:latest` exposed `linux/amd64` only
- Verified workflow logic now computes release tags directly and applies the same multi-arch platform list to all published refs.
