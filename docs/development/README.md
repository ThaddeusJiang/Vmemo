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
- [docs/build_and_run.md](../build_and_run.md)

## 4. Install Dependencies and Prepare Database

```bash
mix setup
```

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

- API docs: [../public-rest-api/README.md](../public-rest-api/README.md)
- Self-hosting: [../build_and_run.md](../build_and_run.md)
- Tooling notes: [../dev/tidewave.md](../dev/tidewave.md)
