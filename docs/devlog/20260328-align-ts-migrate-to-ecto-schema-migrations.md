# Align Typesense migrate with Ecto schema_migrations semantics

## Background
The Typesense migration flow should explicitly mirror Ecto migration tracking behavior.
That means migration state must be persisted inside Typesense, with clear schema migration bookkeeping semantics.

## Changes
- Renamed Typesense migration tracking collection to `ts_schema_migrations`.
- Kept migration state inside Typesense by storing one document per migration version.
- Added `validate_unique_migration_versions/1` to enforce unique migration versions before execution.
- Updated migrate pipeline to validate versions before computing pending migrations.
- Added unit tests for unique-version validation behavior.

## Why this helps
- Makes migration bookkeeping explicit and closer to Ecto's `schema_migrations` model.
- Prevents ambiguous migration ordering caused by duplicate versions.
- Keeps `mix test` idempotent while avoiding repeated execution of applied Typesense migrations.
