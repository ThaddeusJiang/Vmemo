# Add mix task to list Typesense collections

## Context
- Need a mix task to view Typesense collections directly.

## Changes
- Add `mix ts.list_collections` task with optional `--json` and `--names` flags.

## Notes
- Default output prints collection name and document count when available.
