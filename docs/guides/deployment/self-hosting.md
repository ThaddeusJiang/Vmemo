# Self-hosting with Docker Compose

This directory provides the Docker Compose self-hosting entrypoint for Vmemo.

## Quick Start (Recommended)

Use the templates directly under `docs/guides/deployment/self-hosting`.

1. Enter template directory:

```bash
cd docs/guides/deployment/self-hosting
```

2. Copy env template and fill required variables:

```bash
cp .env.example .env
```

Required variables:

- `DATABASE_URL`
- `SECRET_KEY_BASE`
- `ADMIN_PASSWORD`
- `RESEND_API_KEY`
- `TYPESENSE_URL`
- `TYPESENSE_API_KEY`
- `MOONDREAM_API_KEY`
- `OPENROUTER_API_KEY`
- `SENTRY_DSN`

Optional:

- `MOONDREAM_URL` (default `https://api.moondream.ai/v1/`)

If you run Moondream locally, set it in `.env`.

3. Start services:

```bash
docker compose up -d
```

4. Check status and logs:

```bash
docker compose ps
docker compose logs -f
```

5. Open app:

```text
http://localhost:4000
```

## Full Custom Setup

Use this mode when you want full control over `.env`, compose content, or optional public domain exposure.

### 1) Prepare `.env`

Start from template and customize values.

Generate `SECRET_KEY_BASE`:

```bash
mix phx.gen.secret
```

### 2) Prepare Compose

This repository already includes a default compose file as a starting point.

Pay special attention to the `vmemo` storage volume mapping.

PostgreSQL 18 note:

- Mount data volume to `/var/lib/postgresql` (not `/var/lib/postgresql/data`).
- Wrong mount path may cause restart loops or failing health checks.

### 3) Startup and Validation

Bring up services and validate:

```bash
docker compose up -d
docker compose ps
docker compose logs -f vmemo
```

Release startup flow:

1. `bin/vmemo eval "Vmemo.Release.migrate()"`
2. `bin/vmemo start`

Notes:

- This project standardizes on Ash + ash_postgres.
- `Vmemo.Release.migrate()` is the primary release migration entrypoint.
- It executes both AshPostgres repo migrations and Typesense migrations.
- For local migration, prefer Ash tasks such as `mix ash.migrate`; avoid `mix ecto.*`.

Remote IEx example:

```bash
docker exec -it <vmemo_container> /app/bin/vmemo remote
```

### 4) Optional: Expose with Cloudflare Tunnel (Docker)

1. Create a remotely-managed tunnel in Cloudflare Zero Trust and get the token.
2. Set token in `.env`.
3. Start services including tunnel.
4. Verify tunnel status and domain resolution.

Notes:

- Using `--url` forwards public requests only to `vmemo` (`http://vmemo:4000`).
- `postgres` and `typesense` remain internal dependencies and are not exposed directly.
- This Docker mode does not rely on host-side `~/.cloudflared/config.yml`.
- If you already run a host tunnel via `~/.cloudflared/config.yml`, do not enable compose `cloudflared` at the same time.

### 5) Cloudflare 1033 / 530 Quick Troubleshooting

`1033` usually means the hostname is bound to a tunnel but the tunnel has no active connection yet.

1. Check tunnel connection count.
2. Confirm DNS route is bound to the expected tunnel.
3. If host has `~/.cloudflared/config.yml`, ensure it is not hijacking traffic to another tunnel.
4. Validate in order: connector health -> route binding -> domain reachability.

## Additional Notes

- Default image tag is `thaddeusjiang/vmemo`; pin a specific version tag if needed (for example `2026.4.12`).
- Compose startup depends on automatic database + Typesense migration at container start.
- For public access, enable HTTPS at ingress or reverse proxy.
