# Development

This page is a lightweight entry for local development.

Primary source of truth for workflow decisions:

- `/.agents/skills/vmemo-development/SKILL.md`

Use the skill for:

- setup state check
- reset decision
- temporary port conflict handling
- Docker + Mix execution order

## Minimal Commands

From repository root:

```bash
mise trust && mise install
docker compose up -d
mix setup
iex -S mix phx.server
```

Test dependencies:

```bash
docker compose --profile test up -d
```

Reset:

```bash
mix reset
```

Quality gate:

```bash
mix check
```

## Environment Notes

Runtime environment keys are defined in `config/runtime.exs`.

Typical local runtime values:

```toml
[env]
DATABASE_URL = "postgres://postgres:postgres@localhost:10001/vmemo_dev"
TYPESENSE_URL = "http://localhost:10002"
MOONDREAM_URL = "http://localhost:2020/v1/"
```

For test/e2e in Docker Compose, use the test services (for example `10003` / `20002`) in the test runtime environment.

If you use multiple worktrees in parallel, use a dedicated `.env` per worktree.

## Mix Task Reference

Common task groups (details remain in `mix.exs` aliases and task help):

- setup: `mix setup`, `mix deps.get`, `mix db.setup`, `mix ts.setup`, `mix assets.setup`
- run: `mix phx.server`, `iex -S mix phx.server`, `mix phx.routes`
- test/quality: `mix test`, `mix format`, `mix credo --strict`, `mix sobelow --config`, `mix dialyzer`, `mix check`
- reset/migrate: `mix reset`, `mix db.migrate`, `mix db.rollback`, `mix ts.reset`, `mix ts.drop`

For schema changes, use Ash-first migration workflow:

```bash
mix ash_postgres.generate_migrations <name>
mix db.migrate
```

## Related Docs

- REST API: `docs/features/public-rest-api.md`
- API Token: `docs/features/api-tokens.md`
- Docker: `docs/guides/docker/README.md`
- Deployment: `docs/guides/deployment/docker.md`
- E2E tests: `others/e2e-test/README.md`
