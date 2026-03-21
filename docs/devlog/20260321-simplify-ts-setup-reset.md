# 20260321-simplify-ts-setup-reset

## Summary
- Rewrite `ts.setup` and `ts.reset` to mirror the usual `ecto setup/reset` structure.

## Changes
- Added `ts.setup` and `ts.reset` aliases in `mix.exs` so they mirror the usual `ecto setup/reset` structure.
- Added `mix ts.migrate` to start the app and run Typesense migrations.
- Added `mix ts.drop` to start the app and drop Typesense collections.
- Updated `mix setup` to use `ts.setup` directly instead of `ts.reset`.
- Changed `Vmemo.Ts.reset/0` to only drop collections.

## Notes
- Verification was not run in this change.
