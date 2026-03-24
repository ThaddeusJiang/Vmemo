# 2026-03-24 Default moondream URL in runtime config

## Summary

Added a default `MOONDREAM_URL` in prod runtime config so containerized setups can enqueue and run moondream-related Oban jobs without requiring an explicit URL override.

## Changes

- set `MOONDREAM_URL` default to `https://api.moondream.ai/v1` in `config/runtime.exs` for `prod` only
- kept Docker Compose focused on env passthrough instead of application defaults

## Notes

- callers can still override `MOONDREAM_URL` from `.env` when using a self-hosted moondream service
- dev and test keep their existing localhost defaults
- this restores the expected default external API endpoint in prod code paths
