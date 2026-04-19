# Development

This guide focuses on local development workflows and project-available `mix` tasks.

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

By default, `docker compose up -d` starts dev Postgres and Typesense only. Test-scoped containers (`postgres-test`, `typesense-test`) use Compose profile `test` and are not started unless you opt in.

```bash
docker compose up -d
```

To run `mix test` against local Docker dependencies, start the test profile as well:

```bash
docker compose --profile test up -d
```

3. Install dependencies and initialize the app:

```bash
mix setup
```

4. Run the app locally:

```bash
iex -S mix phx.server
```

5. Open the app:

```text
http://localhost:4000
```

## Mix Tasks By Scenario

This section lists project-available tasks used in day-to-day development, grouped by usage scenario.

### 1. Setup

- `mix setup`
  - Expands to: `mix deps.get`, `mix db.setup`, `mix ts.setup`, `mix assets.setup`, `mix assets.build`
- `mix deps.get`
- `mix db.setup`
  - Expands to: `mix db.create`, `mix db.migrate`, `mix db.seed`
- `mix db.create`
  - Expands to: `mix ash_postgres.create`
- `mix db.migrate`
  - Expands to: `mix ash.migrate`
- `mix db.seed`
  - Expands to: `mix run priv/repo/seeds.exs`
- `mix ts.setup`
  - Expands to: `mix ts.migrate`
- `mix assets.setup`
  - Expands to: `mix tailwind.install --if-missing`, `mix esbuild.install --if-missing`
- `mix assets.build`
  - Expands to: `mix tailwind vmemo`, `mix esbuild vmemo`

### 2. Start Development

- `mix phx.server`
- `iex -S mix phx.server`
- `mix phx.routes`
- `mix compile`

### 3. Test And Quality

- `mix test`
  - Alias behavior: ensure DB and Typesense migration tasks run before tests
- `mix check`
  - Runs formatter check, compile warnings as errors, xref cycles, credo, sobelow, hex audit, deps unused check, test with warnings as errors, dialyzer
- `mix format`
- `mix format --check-formatted`
- `mix credo --strict`
- `mix sobelow --config`
- `mix dialyzer --format short`
- `mix xref graph --format cycles --label compile --fail-above 0`

### 4. Reset And Recovery

- `mix reset`
  - Expands to: `mix db.reset`, `mix ts.reset`
- `mix db.reset`
  - Expands to: `mix db.drop`, `mix db.setup`
- `mix db.drop`
  - Expands to: `mix ash_postgres.drop`
- `mix ts.reset`
  - Expands to: internal Typesense drop step, then `mix ts.setup`
- `mix ts.drop`
  - Drops Typesense collections managed by the schema

### 5. Database Migrate And Rollback

- `mix db.migrate`
- `mix db.rollback`
  - Expands to: `mix ash_postgres.rollback`
- `mix ash.migrate`
- `mix ash_postgres.rollback`

### 6. Search Index (Typesense)

- `mix ts.migrate`
- `mix ts.setup`
- `mix ts.reset`
  - Runs reset flow including an internal drop step
- `mix ts.drop`
- `mix ts.collections`
  - List all Typesense collections
- `mix ts.collection <collection_name>`
  - Show one collection definition

### 7. Assets

- `mix assets.setup`
- `mix assets.build`
- `mix assets.deploy`
  - Expands to: `mix tailwind vmemo --minify`, `mix esbuild vmemo --minify`, `mix phx.digest`

## Common Workflows

- First-time local setup:
  1. `mise install`
  2. `docker compose up -d`
  3. `mix setup`
  4. `iex -S mix phx.server`

- Run tests locally with Docker test dependencies:
  1. `docker compose --profile test up -d`
  2. `mix test`

- Full local reset:
  1. `pkill -f "mix phx.server" || true`
  2. `docker compose down -v`
  3. `docker compose up -d`
  4. `mix reset`

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
- Docker (entry): `docs/guides/docker/README.md`
- Deployment: `docs/guides/deployment/docker.md`
