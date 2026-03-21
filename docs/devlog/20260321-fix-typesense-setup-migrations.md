# 20260321-fix-typesense-setup-migrations

## Summary
- Fix `mix setup` so Typesense setup always runs all files under `priv/ts/migrations`.

## Changes
- Updated `Vmemo.Ts.reset/0` to call a new `migrate/0` function instead of hardcoding `change_1..change_3`.
- Added `Vmemo.Ts.migrate/0` to load and execute sorted Typesense migration files from `priv/ts/migrations/*.exs`.
- Fixed `SmallSdk.Typesense.create_collection/1` to use Req's top-level `receive_timeout` option instead of invalid `connect_options: [receive_timeout: ...]`.
- Documented in the dev README that `mix setup` also rebuilds Typesense collections and runs Typesense migrations.

## Notes
- New Typesense schema changes only need a new file in `priv/ts/migrations`; `mix setup` will pick it up automatically.
- Verification was not run in this change.
