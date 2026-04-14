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

The repository includes a root `docker-compose.yml` for Postgres, Typesense, and related services.

By default, `docker compose up -d` starts **dev** Postgres and Typesense only. Test-scoped containers (`postgres-test`, `typesense-test`) use Compose profile `test` and are not started unless you opt in.

```bash
docker compose up -d
```

To run `mix test` against local Docker dependencies, start the test profile as well (one-shot):

```bash
docker compose --profile test up -d
```

Or keep dev services up and add test services only:

```bash
docker compose --profile test up -d postgres-test typesense-test
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

Run the test suite (requires test Postgres and Typesense on ports `25432` / `28108`, or set `POSTGRES_PORT` / `TYPESENSE_URL` accordingly):

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
`docker compose up -d`, `mix setup`). If you also run `mix test` locally with Docker,
use `docker compose --profile test up -d` instead of `docker compose up -d` after the reset.

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

- REST API: `docs/features/public-rest-api.md`
- API Token: `docs/features/api-tokens.md`
- Deployment: `docs/guides/deployment/docker-prod-run.md`
