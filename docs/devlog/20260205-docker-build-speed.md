# Docker build speed

## Goal
- Speed up Docker builds locally and in GitHub Actions while keeping Elixir available in the runtime container.

## Changes
- Enable BuildKit cache mounts for Hex, Mix, deps, and _build.
- Remove duplicate `mix deps.get` and set `MIX_ENV` before dependency resolution.
- Reduce runner apt packages to runtime-only libraries while keeping Elixir.
- Keep assets build in the image build for production compatibility.

## Notes
- BuildKit is required to use cache mounts.
- CI can pass `--build-arg MIX_ENV=prod` and local dev can pass `--build-arg MIX_ENV=dev` as needed.

## CI
- Enable GitHub Actions buildx cache (type=gha) for Docker builds.
- Pass MIX_ENV=prod in Docker builds.

## Follow-up
- Remove CI build args for MIX_ENV since prod is always enforced in Dockerfile.

## Follow-up
- Pin MIX_ENV to prod in Dockerfile; remove ARG usage.
