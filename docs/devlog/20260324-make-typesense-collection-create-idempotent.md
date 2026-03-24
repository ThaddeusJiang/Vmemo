# 2026-03-24 Make Typesense collection create idempotent

## Summary

Allowed Typesense collection creation to be rerun safely so Docker startup does not crash after the collections already exist.

## Changes

- treated `Conflict` from `Typesense.create_collection/1` as success for the `photos` and `notes` collections
- kept other Typesense operations strict so update and delete failures still surface immediately
- unblocked repeated `mix ts.migrate` runs from the Docker entrypoint

## Files

- `lib/vmemo/ts.ex`
