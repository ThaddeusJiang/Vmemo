# 20260321-ci-split-setup-and-disable-ts-embedding-in-test

## Summary
- Keep `mix setup` fully inclusive for local use, but split setup tasks in CI.

## Changes
- Restored `ts.setup` inside the default `mix setup` alias.
- Updated GitHub Actions to avoid `mix setup`; CI now runs `mix ash_postgres.create --quiet`, `mix ash.migrate --quiet`, `mix ts.setup`, then `mix test`.
- Added `config :vmemo, typesense_image_embedding: false` in `config/test.exs`.
- Updated `Vmemo.Ts.change_1/0` to conditionally include `image_embedding` field based on `:typesense_image_embedding`.

## Notes
- This removes the CI dependency on first-time model downloads while keeping local setup unchanged.
