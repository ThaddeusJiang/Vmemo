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
docker compose --profile proxy up -d
mix setup
iex -S mix phx.server
```

`mise install` installs the required Node.js runtime as well as Elixir/Erlang.
`mix setup` installs external frontend packages with `npm ci --prefix assets`
before building CSS and JavaScript.

Open the app directly:

```text
http://localhost:4000
```

Storage image responses work when the browser connects directly to Phoenix.
Use the optional Nginx proxy on port `4080` only when validating
`X-Accel-Redirect` storage acceleration or proxy-specific behavior locally.

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

External frontend asset dependencies are managed by npm in `assets/package.json`
and locked by `assets/package-lock.json`. Phoenix-provided JavaScript packages
(`phoenix`, `phoenix_html`, `phoenix_live_view`) and the `esbuild` build tool
remain managed by Mix deps. Do not copy external package source into
`assets/vendor`.

Common asset commands:

```bash
mix assets.setup
mix assets.build
mix assets.deploy
```

Direct npm equivalents:

```bash
npm ci --prefix assets
npm run build --prefix assets
npm run deploy --prefix assets
```

The npm build commands only compile CSS. `mix assets.build` and
`mix assets.deploy` run the npm CSS build first and then bundle JavaScript with
the Mix `esbuild` wrapper.

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
