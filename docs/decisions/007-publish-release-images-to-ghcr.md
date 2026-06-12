# Publish Release Images to GHCR

Date: 2026-06-12

Status: accepted

## Context

Vmemo previously published release images to Docker Hub. The release workflow now needs to match the GitHub Packages pattern used by the reference `save_it` workflows: GitHub releases drive Docker image publishing, and manual prereleases can publish a test image immediately.

The repository already avoids GitHub cache and artifact storage, and release workflows should remain simple enough to operate without a split manifest assembly pipeline.

## Decision

Publish Vmemo release images to GitHub Container Registry at `ghcr.io/thaddeusjiang/vmemo`.

- Stable GitHub releases publish the release version tag and `latest`.
- Prerelease GitHub releases publish the prerelease version tag and `stag`.
- `release.yml` handles published GitHub releases.
- `release-manual.yml` creates a published prerelease from a manually supplied tag, then publishes the GHCR image.
- `docker-publish.yml` is the reusable image publishing workflow for both release paths.
- Docker Hub publishing and Docker Hub description updates are no longer maintained.

## Others

This supersedes the Docker Hub publishing statements in:

- [005-github-actions-no-cache-or-artifacts](005-github-actions-no-cache-or-artifacts.md)
- [005-github-actions-no-github-cache](005-github-actions-no-github-cache.md)
