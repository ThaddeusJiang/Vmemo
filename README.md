# Vmemo

[![Docker Pulls](https://img.shields.io/docker/pulls/thaddeusjiang/vmemo)](https://hub.docker.com/r/thaddeusjiang/vmemo)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](https://github.com/ThaddeusJiang/Vmemo/blob/develop/LICENSE)

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
- REST API for external integrations.
- Responsive web UI for desktop and mobile.

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
    image: postgres:18
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
    image: typesense/typesense:30.1
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

## Environment Variables

| Variable             | Required | Description                                                        |
| -------------------- | -------- | ------------------------------------------------------------------ |
| `DATABASE_URL`       | Yes      | PostgreSQL connection URL                                          |
| `TYPESENSE_URL`      | Yes      | Typesense endpoint                                                 |
| `TYPESENSE_API_KEY`  | Yes      | Typesense API key                                                  |
| `MOONDREAM_URL`      |          | Moondream API endpoint (`https://api.moondream.ai/v1/` default)    |
| `MOONDREAM_API_KEY`  | Yes      | Moondream API key                                                  |
| `OPENROUTER_API_KEY` | Yes      | OpenRouter API key for chat features                               |
| `RESEND_API_KEY`     | Yes      | Resend API key for email                                           |
| `SENTRY_DSN`         | Yes      | Sentry DSN                                                         |
| `SENTRY_ENV`         |          | Sentry environment (`production`, `staging`, etc.; `prod` default) |
| `SECRET_KEY_BASE`    | Yes      | Phoenix secret key base                                            |
| `PHX_SERVER`         |          | Enable Phoenix server in runtime                                   |
| `PHX_HOST`           |          | Public host name (`vmemo.app` default)                             |
| `PORT`               |          | App port (`4000` default)                                          |
| `POOL_SIZE`          |          | DB pool size (`10` default)                                        |
| `ECTO_IPV6`          |          | Enable IPv6 when set to `true` or `1`                              |
| `ADMIN_PASSWORD`     | Yes      | Admin password for protected actions                               |

## Tech Stack

- Elixir + Phoenix LiveView
- Ash Framework + Oban
- PostgreSQL + Typesense
- Tailwind CSS + daisyUI

## Architecture

Ash resource diagrams (PNG) are generated in CI with [`mix ash.generate_resource_diagrams`](https://hexdocs.pm/ash/Mix.Tasks.Ash.GenerateResourceDiagrams.html) and committed under [`lib/vmemo/`](https://github.com/ThaddeusJiang/Vmemo/tree/develop/lib/vmemo). Stable URLs (branch `develop`, raw GitHub content):

| Domain  | Resource diagram (PNG) |
| ------- | ------------------------ |
| Account | [`account-mermaid-class-diagram.png`](https://raw.githubusercontent.com/ThaddeusJiang/Vmemo/develop/lib/vmemo/account-mermaid-class-diagram.png) |
| Admin   | [`admin-mermaid-class-diagram.png`](https://raw.githubusercontent.com/ThaddeusJiang/Vmemo/develop/lib/vmemo/admin-mermaid-class-diagram.png) |
| Ai      | [`ai-mermaid-class-diagram.png`](https://raw.githubusercontent.com/ThaddeusJiang/Vmemo/develop/lib/vmemo/ai-mermaid-class-diagram.png) |
| Chat    | [`chat-mermaid-class-diagram.png`](https://raw.githubusercontent.com/ThaddeusJiang/Vmemo/develop/lib/vmemo/chat-mermaid-class-diagram.png) |
| Memo    | [`memo-mermaid-class-diagram.png`](https://raw.githubusercontent.com/ThaddeusJiang/Vmemo/develop/lib/vmemo/memo-mermaid-class-diagram.png) |

If your default branch is `main` instead of `develop`, use `main` in place of `develop` in these URLs.

## Security Notes

- Use strong random values for `SECRET_KEY_BASE` and `ADMIN_PASSWORD`.
- Keep API tokens private and rotate periodically.
- Use HTTPS in production.
- Store secrets in environment variables or a secrets manager.

## License

Apache License 2.0
