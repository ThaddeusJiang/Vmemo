# Vmemo

[![GitHub Repository](https://img.shields.io/badge/GitHub-ThaddeusJiang%2FVmemo-181717?logo=github)](https://github.com/ThaddeusJiang/Vmemo)
[![Last Commit](https://img.shields.io/github/last-commit/ThaddeusJiang/Vmemo)](https://github.com/ThaddeusJiang/Vmemo/commits)
[![License](https://img.shields.io/github/license/ThaddeusJiang/Vmemo)](https://github.com/ThaddeusJiang/Vmemo/LICENSE)
[![Docker Pulls](https://img.shields.io/docker/pulls/thaddeusjiang/vmemo)](https://hub.docker.com/r/thaddeusjiang/vmemo)

Vmemo is a visual memory app for capturing life with photos, searching with AI, and reviewing moments quickly without writing long text notes.

## Why Vmemo

Text-only journaling is easy to forget and hard to revisit. Vmemo focuses on visual memory:

- Upload and organize photos quickly.
- Search by text or image similarity.
- Generate captions and OCR text with AI.
- Access your data from the web app and Public API.

## Features

- Photo upload and management (multi-upload, drag-and-drop, paste).
- AI-powered search (text and image similarity).
- AI caption and OCR extraction.
- API token management.
- Public REST API for external integrations.
- Responsive web UI for desktop and mobile.

## Docker Image Platforms

Vmemo provides architecture-specific Docker images:

- `thaddeusjiang/vmemo:<version>-amd64`
- `thaddeusjiang/vmemo:<version>-arm64`

Pick the image by your host CPU:

- Apple Silicon (M1/M2/M3/M4): use `-arm64`
- Most cloud Linux servers on Intel/AMD CPUs: use `-amd64`

Examples:

```bash
docker pull thaddeusjiang/vmemo:2026.3.28-arm64
docker pull thaddeusjiang/vmemo:2026.3.28-amd64
```

## Self-hosting

You can also run Vmemo on your local machine or self-host it.
We also publish official Docker images for Vmemo on [Docker hub](https://hub.docker.com/r/thaddeusjiang/vmemo)

### 1. Create `.env`

```bash
PHX_HOST=localhost
PHX_SERVER=true

SECRET_KEY_BASE=replace_with_a_long_random_secret
ADMIN_PASSWORD=replace_with_a_strong_admin_password

# Optional AI integrations
OPENROUTER_API_KEY=
MOONDREAM_API_KEY=

# DevOps
RESEND_API_KEY=
SENTRY_DSN=
```

Generate a secret with:

```bash
openssl rand -hex 64
```

### 2. Create `docker-compose.yml`

```yaml
services:
  vmemo:
    image: thaddeusjiang/vmemo:<version>-amd64
    command: ["start"]
    restart: on-failure
    environment:
      DATABASE_URL: postgres://postgres:postgres@postgres/vmemo
      TYPESENSE_URL: http://typesense:8108
      TYPESENSE_API_KEY: xyz
      SECRET_KEY_BASE: ${SECRET_KEY_BASE:?SECRET_KEY_BASE is required}
      ADMIN_PASSWORD: ${ADMIN_PASSWORD:?ADMIN_PASSWORD is required}
      RESEND_API_KEY: ${RESEND_API_KEY:?RESEND_API_KEY is required}
      SENTRY_DSN: ${SENTRY_DSN:?SENTRY_DSN is required}
    env_file:
      - .env
    ports:
      - "4000:4000"
    volumes:
      - ./vmemo_data/storage:/app/storage
    depends_on:
      postgres:
        condition: service_healthy
      typesense:
        condition: service_healthy

  postgres:
    image: postgres:17
    restart: on-failure
    hostname: postgres
    ports:
      - "5432:5432"
    volumes:
      - ./vmemo_data/pg-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d vmemo"]
      interval: 2s
      timeout: 5s
      retries: 20
      start_period: 5s
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: vmemo

  typesense:
    image: typesense/typesense:27.1
    restart: on-failure
    hostname: typesense
    ports:
      - "8108:8108"
    volumes:
      - ./vmemo_data/ts-data:/data
    command: "--data-dir /data --api-key=xyz --enable-cors"
    healthcheck:
      test:
        [
          "CMD-SHELL",
          "bash -lc 'exec 3<>/dev/tcp/127.0.0.1/8108 && printf \"GET /health HTTP/1.1\\r\\nHost: localhost\\r\\nConnection: close\\r\\n\\r\\n\" >&3 && grep -q \"200 OK\" <&3'",
        ]
      interval: 2s
      timeout: 5s
      retries: 30
      start_period: 5s
```

### 3. Start Services

```bash
docker compose up -d
```

Open `http://localhost:4000`.

Startup flow in container:

1. `bin/vmemo eval "Vmemo.Release.migrate()"`
2. `bin/vmemo start`

Migration note:

- Vmemo uses Ash + ash_postgres for data access and schema changes.
- `Vmemo.Release.migrate()` is the preferred release entrypoint.
- It runs both AshPostgres repo migrations and Typesense migrations.
- For local setup/reset workflow, prefer `mix setup` and `mix reset`.
- This project depends on both database and Typesense, so setup/reset should usually run both sides together.
- Use standalone DB commands only for targeted maintenance.

Remote IEx (release mode):

```bash
docker exec -it <container_name> /app/bin/vmemo remote
```

### Optional: Define a Public Domain via Cloudflare Tunnel

Use the Cloudflare Tunnel CLI guide to complete the full tunnel setup, including tunnel creation, DNS route, domain mapping, and service run commands:

- `docs/hexdocs/cloudflare-tunnel-cli.md`

## Public API

Vmemo includes a token-based REST API for photo operations and integrations.

### Authentication

Include an API token in the `Authorization` header:

```bash
Authorization: Bearer vmemo_your_token_here
```

Create a token in the web UI:

1. Sign in to Vmemo.
2. Open `/tokens`.
3. Create a token.
4. Copy the token immediately.

### Base URL

```text
http://localhost:4000/api/v1
```

### Endpoints

Upload a photo:

```bash
curl -X POST http://localhost:4000/api/v1/photos \
  -H "Authorization: Bearer vmemo_your_token" \
  -F "file=@/path/to/image.jpg" \
  -F "note=My photo note"
```

Get a photo:

```bash
curl -X GET http://localhost:4000/api/v1/photos/photo-uuid \
  -H "Authorization: Bearer vmemo_your_token"
```

Delete a photo:

```bash
curl -X DELETE http://localhost:4000/api/v1/photos/photo-uuid \
  -H "Authorization: Bearer vmemo_your_token"
```

Example error response:

```json
{
  "status": "error",
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Invalid or missing API token"
  }
}
```

## Required Environment Variables (Production)

| Variable          | Description                                        |
| ----------------- | -------------------------------------------------- |
| `DATABASE_URL`    | PostgreSQL connection URL                          |
| `ADMIN_PASSWORD`  | Admin password for protected actions               |
| `SECRET_KEY_BASE` | Phoenix secret key base                            |
| `SENTRY_DSN`      | Sentry DSN                                         |
| `SENTRY_ENV`      | Sentry environment (`production`, `staging`, etc.) |
| `RESEND_API_KEY`  | Resend API key for email                           |

## Optional Environment Variables

| Variable             | Description                            |
| -------------------- | -------------------------------------- |
| `TYPESENSE_URL`      | Typesense endpoint                     |
| `TYPESENSE_API_KEY`  | Typesense API key                      |
| `MOONDREAM_URL`      | Moondream API endpoint                 |
| `MOONDREAM_API_KEY`  | Moondream API key                      |
| `OPENROUTER_API_KEY` | OpenRouter API key for chat features   |
| `PHX_HOST`           | Public host name (`vmemo.app` default) |
| `PORT`               | App port (`4000` default)              |
| `POOL_SIZE`          | DB pool size (`10` default)            |
| `ECTO_IPV6`          | Enable IPv6 when set to `true` or `1`  |
| `PHX_SERVER`         | Enable Phoenix server in runtime       |

## Tech Stack

- Elixir + Phoenix LiveView
- Ash Framework + Oban
- PostgreSQL + Typesense
- Tailwind CSS + daisyUI

## Security Notes

- Use strong random values for `SECRET_KEY_BASE` and `ADMIN_PASSWORD`.
- Keep API tokens private and rotate periodically.
- Use HTTPS in production.
- Store secrets in environment variables or a secrets manager.

## License

MIT
