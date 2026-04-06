# Development Setup

This guide is written in a practical contributor style and focuses on getting a local Vmemo environment ready quickly.

## Prerequisites

- macOS or Linux
- Docker runtime
- `mise` for Elixir/Erlang version management

## Quickstart

1. Install toolchain versions from `mise.toml`:

```bash
mise install
```

2. Start local dependencies:

Create local compose file from the committed example:

```bash
cp docker-compose.example.yml docker-compose.yml
```

Then start local dependencies:

```bash
docker compose up -d
```

3. Install dependencies and initialize the app:

```bash
mix setup
```

`mix setup` only initializes shared development data and does not create local test users or test API tokens.
For e2e auth fixtures, use the SQL seed flow in `e2e-test/fixtures/prepare-e2e-auth.sql`.

4. Run the app locally:

```bash
iex -S mix phx.server
```

5. Open the app:

```text
http://localhost:4000
```

## Daily Workflow

Run the test suite:

```bash
mix test
```

Inspect routes:

```bash
mix phx.routes
```

Format code:

```bash
mix format
```

Reset local DB + Typesense state when needed:

```bash
mix ts.reset
```

For a full local reset workflow, use the Local Development reset sequence
(`pkill -f "mix phx.server" || true`, `docker compose down -v`,
`docker compose up -d`, `mix setup`).

## Local Environment Variables

If needed, set local overrides in `mise.local.toml`:

```toml
[env]
OPENROUTER_API_KEY = "your-openrouter-api-key"
```

Runtime environment keys are defined in `config/runtime.exs`.

## Contributor Checklist

Before opening a pull request:

1. Run `mix format`.
2. Run `mix test`.
3. Validate the feature path manually in the browser.
4. Update docs for any user-facing or developer-facing behavior changes.

## Related Docs

- Public REST API: `docs/features/public-rest-api.md`
- API Token Guide: `docs/features/api-tokens.md`
- Deployment: `docs/guides/deployment/docker-prod-run.md`
