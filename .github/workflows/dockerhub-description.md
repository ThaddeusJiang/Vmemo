# Vmemo

Vmemo is a visual memo app for capturing life with images, searching with AI, and reviewing moments quickly without writing long text notes.

## Zeabur One-Click Self-Hosting

Vmemo supports one-click self-hosting on Zeabur.

[Self-host on Zeabur](https://zeabur.com/templates/H3EL85)

[![Deploy on zeabur](https://zeabur.com/button.svg)](https://zeabur.com/templates/H3EL85)

## Docker Image

Official image:

```bash
docker pull thaddeusjiang/vmemo
```

You can run Vmemo with Docker Compose.

### 1. Create `.env`

```bash
PHX_HOST=localhost
PHX_SERVER=true

SECRET_KEY_BASE=replace_with_a_long_random_secret
ADMIN_TOKEN=replace_with_a_strong_admin_token

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
    image: thaddeusjiang/vmemo
    command: ["start"]
    restart: on-failure
    environment:
      DATABASE_URL: postgres://postgres:postgres@postgres/vmemo
      TYPESENSE_URL: http://typesense:8108
      TYPESENSE_API_KEY: xyz
      SECRET_KEY_BASE: ${SECRET_KEY_BASE:?SECRET_KEY_BASE is required}
      ADMIN_TOKEN: ${ADMIN_TOKEN:?ADMIN_TOKEN is required}
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

### 3. Start services

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
| `MOONDREAM_URL`      |          | Moondream API endpoint (`https://api.moondream.ai/v1/` default)   |
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
| `ADMIN_TOKEN`        | Yes      | Admin token for protected actions                                  |

## More docs

- Self-hosting docs: https://github.com/ThaddeusJiang/Vmemo/tree/develop/docs/guides/self-hosting
- Zeabur docs: https://github.com/ThaddeusJiang/Vmemo/tree/develop/docs/guides/self-hosting/zeabur
