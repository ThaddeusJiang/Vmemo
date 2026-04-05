# Development Setup

This guide explains how to set up a local Vmemo development environment.

## Prerequisites

- macOS host environment.
- `mise` installed for Elixir/Erlang version management.
- Docker Desktop (or compatible local Docker runtime).

## 1. Install Toolchain

Install project-defined Elixir/Erlang versions:

```bash
mise install
```

## 2. Start Dependencies

Start local infrastructure services:

```bash
docker compose up -d
```

## 3. Configure Local Environment

Create local environment overrides when needed:

```toml
# mise.local.toml
[env]
OPENROUTER_API_KEY = "your-openrouter-api-key"
```

For full runtime variables, see:

- `config/runtime.exs`
- [docs/guides/deployment/docker-prod-run.md](../deployment/docker-prod-run.md)

## 4. Install Dependencies and Prepare Database

```bash
mix setup
```

`mix setup` prepares both database and Typesense in this project:

- Database setup and migrations
- Typesense schema setup and migrations

For daily maintenance, prefer:

```bash
mix reset
```

Use standalone `mix db.*` or `mix ts.*` commands only for targeted fixes.

## 5. Run the App

Run the Phoenix server in local development:

```bash
iex -S mix phx.server
```

Open `http://localhost:4000`.

## Useful Commands

```bash
mix test
mix phx.routes
mix format
```

## Related Docs

- API docs: [../../features/public-rest-api.md](../../features/public-rest-api.md)
- Prod Docker run: [../deployment/docker-prod-run.md](../deployment/docker-prod-run.md)
- Tooling notes: [tidewave.md](tidewave.md)
