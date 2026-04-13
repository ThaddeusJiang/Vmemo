# Use Elixir Release as the Docker Startup Entrypoint

Date: 2026-03-26

Status: accepted

## Context

- The previous Docker runner path used Elixir + Mix (`mix ash.migrate`, `mix ts.migrate`, `mix phx.server`).
- The project moved to a single prod Docker path and needed a more stable, predictable production startup.
- Release startup (`bin/vmemo start`) standardizes runtime behavior and avoids using Mix as the online main process dependency.

## Decision

**Switch back to Elixir Release startup.**

- Run `mix release` in build stage.
- Copy release artifacts only into the runner image.
- Container startup flow:
  1. `bin/vmemo eval "Vmemo.Release.migrate()"`
  2. `bin/vmemo start`
- `Vmemo.Release.migrate()` runs both AshPostgres repo migrations and Typesense migrations.

## Consequences

- Pros:
  1. Unified production startup entrypoint.
  2. Runner image no longer relies on Mix as the default runtime path.
  3. Compose and CI app startup commands can both use `start`.
- Trade-offs:
  1. Need to maintain the release migration entrypoint (`Vmemo.Release`).
  2. Online temporary tasks should use `bin/vmemo eval ...` instead of defaulting to `mix ...`.
