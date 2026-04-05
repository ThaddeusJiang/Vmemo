# Deployment

Vmemo keeps a single production-image path for Docker workflows.

## Image Policy

- Use the root `Dockerfile` for both local production-like runs and CI image publishing.
- Build and run with `MIX_ENV=prod`.
- Do not maintain a separate development Docker image path.

## Local Dependency Services

Use the repository root compose files for dependency services such as PostgreSQL and Typesense.

Create local compose file from the committed example:

```bash
cp docker-compose.example.yml docker-compose.yml
```

Start dependencies:

```bash
docker compose -f docker-compose.yml up -d postgres typesense
```

## Build and Run the Production Image Locally

Build:

```bash
docker build -t vmemo:local .
```

Run:

```bash
docker run --rm -p 4000:4000 \
  --env-file .env \
  vmemo:local
```

The release runs migrations first, then starts the app.

## Remote IEx for Release Runtime

Find the running container:

```bash
docker ps --format '{{.Names}}'
```

Connect to a running release:

```bash
docker exec -it <container_name> /app/bin/vmemo remote
```

Example command after connecting:

```elixir
Vmemo.Release.migrate()
```

Exit remote IEx with `Ctrl+C` twice.

## Host-Mode App Runtime

Run directly on host for development:

```bash
iex -S mix phx.server
```

One-off setup or maintenance tasks can still be run from host shell, for example `mix ts.setup` and `mix ts.reset`.
