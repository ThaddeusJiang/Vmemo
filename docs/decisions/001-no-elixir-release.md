# Do Not Use Elixir Release; Use Mix Inside Docker

Date: 2026-02-08

Status: superseded by [002-use-elixir-release.md](./002-use-elixir-release.md)

## Context

- In production/preview Docker deployment, the runner needed to choose between **Elixir Release** (`mix release` + `bin/vmemo start`) and **Elixir image + Mix** (`mix phx.server`, `mix ash.migrate`, etc.).
- Common Release benefits include a slimmer runtime image, no Mix dependency, and a single executable entrypoint.
- At that time, this project prioritized direct use of Mix and IEx in containers for operations and debugging while still running the app in prod mode.

## Decision

**Do not use Elixir Release.** The runner uses the official Elixir image and keeps running app/runtime tasks with Mix (`mix phx.server`, `mix ash.migrate`) and one-off jobs (for example `mix ts.reset`) to align with local development workflows.

Reasons:

1. **Operations and debugging**: run `mix` and `iex` inside containers without rebuilding images.
2. **Simplicity and consistency**: same command set in local and Docker (`MIX_ENV=prod` in production).
3. **Cost vs. benefit**: Release gains were not urgent at this project scale, while maintenance overhead increased.

## Others

- Build/runtime details: [docker-prod-run.md](../guides/deployment/docker-prod-run.md).
- Re-evaluate Release if future scale or security policies require removing Mix from runtime containers.
