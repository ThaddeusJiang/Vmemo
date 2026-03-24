# Remove Redundant Root Prod Compose File

Date: 2026-03-21

## Goal

Remove the redundant root `docker-compose.prod.yml` wrapper to avoid duplicate compose entry points.

## Changes

- Deleted root `docker-compose.prod.yml`.
- Kept `_prod/docker-compose.yml` as the single compose entry point used by e2e and CI.
