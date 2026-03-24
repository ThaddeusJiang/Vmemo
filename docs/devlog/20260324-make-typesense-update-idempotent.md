# Make Typesense update idempotent

## Context

The Docker entrypoint reruns `mix ts.migrate` on every container start. Existing local Typesense data already contained the `note_ids` field on the `photos` collection, so the migration crashed on repeated startup.

## Changes

- added an idempotent update helper for Typesense collection updates
- treated the `is already part of the schema` response as success for repeated field additions
- switched `change_2` and `change_3` to use the idempotent update helper

## Result

Repeated Docker startup no longer crashes when Typesense already contains the migrated fields.
