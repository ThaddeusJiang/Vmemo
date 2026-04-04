# Vmemo

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

Apple Silicon (M1/M2/M3/M4/M5): use `-arm64`

```bash
docker pull thaddeusjiang/vmemo:2026.3.28-arm64
```

Intel/AMD CPUs: use `-amd64`

```bash
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

# Integrations
OPENROUTER_API_KEY=replace_with_your_openrouter_api_key
MOONDREAM_API_KEY=replace_with_your_moondream_api_key

# DevOps
RESEND_API_KEY=replace_with_your_resend_api_key
SENTRY_DSN=https://public@example.com/1
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

## API Docs

Public API documentation has been moved to:

- [Public REST API](docs/public-rest-api/README.md)
- [API Tokens Guide](docs/api-tokens.md)

## Environment Variables

| Variable             | Required | Description                                        |
| -------------------- | -------- | -------------------------------------------------- |
| `DATABASE_URL`       | Yes      | PostgreSQL connection URL                          |
| `ADMIN_PASSWORD`     | Yes      | Admin password for protected actions               |
| `SECRET_KEY_BASE`    | Yes      | Phoenix secret key base                            |
| `RESEND_API_KEY`     | Yes      | Resend API key for email                           |
| `TYPESENSE_URL`      | Yes      | Typesense endpoint                                 |
| `TYPESENSE_API_KEY`  | Yes      | Typesense API key                                  |
| `MOONDREAM_URL`      | No       | Moondream API endpoint (`https://api.moondream.ai/v1/` default) |
| `MOONDREAM_API_KEY`  | Yes      | Moondream API key                                  |
| `OPENROUTER_API_KEY` | Yes      | OpenRouter API key for chat features               |
| `SENTRY_DSN`         | Yes      | Sentry DSN                                         |
| `SENTRY_ENV`         | No       | Sentry environment (`production`, `staging`, etc.; `prod` default) |
| `PHX_SERVER`         | No       | Enable Phoenix server in runtime                   |
| `PHX_HOST`           | No       | Public host name (`vmemo.app` default)             |
| `PORT`               | No       | App port (`4000` default)                          |
| `POOL_SIZE`          | No       | DB pool size (`10` default)                        |
| `ECTO_IPV6`          | No       | Enable IPv6 when set to `true` or `1`              |

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
