# Deployment Modes (Self-hosting Scope)

This guide documents supported deployment modes by dependency ownership.

## Directory Layout

```text
docs/guides/deployment/self-hosting/
├── local-machine/
│   ├── .env.example
│   └── docker-compose.yml
├── zeabur/
│   ├── .env.example
│   ├── vmemo.yml
│   └── README.md
└── fly/
    └── .env.example
```

## Dependency Matrix

| Mode | Vmemo App | PostgreSQL | Typesense | Moondream |
| --- | --- | --- | --- | --- |
| Local machine | self-hosted | self-hosted | self-hosted | self-hosted (`moondream-station`) |
| Zeabur | self-hosted | self-hosted (Zeabur service) | self-hosted (Zeabur service) | managed service (`moondream.ai`) |
| Fly.io | self-hosted | managed service | managed service | managed service (`moondream.ai`) |

## 1) Local Machine

Use this when all core dependencies run on your own machine.

### Quick start

```bash
cd docs/guides/deployment/self-hosting/local-machine
cp .env.example .env
docker compose up -d
```

Then verify:

```bash
docker compose ps
docker compose logs -f
```

App URL:

```text
http://localhost:4000
```

### Templates

- `docs/guides/deployment/self-hosting/local-machine/.env.example`
- `docs/guides/deployment/self-hosting/local-machine/docker-compose.yml`

## 2) Zeabur

Use this when Vmemo runs on Zeabur, with Zeabur-hosted PostgreSQL and Typesense, and managed `moondream.ai`.

### Copy-ready env

```bash
cd docs/guides/deployment/self-hosting/zeabur
cp .env.example .env
```

### Templates

- `docs/guides/deployment/self-hosting/zeabur/.env.example`
- `docs/guides/deployment/self-hosting/zeabur/vmemo.yml`
- `docs/guides/deployment/self-hosting/zeabur/README.md`

Note:

- Do not use `moondream-station` in Zeabur mode.

## 3) Fly.io

Use this when only Vmemo is self-hosted on Fly.io and all dependencies are external managed services.

### Copy-ready env

```bash
cd docs/guides/deployment/self-hosting/fly
cp .env.example .env
```

### Templates

- `docs/guides/deployment/self-hosting/fly/.env.example`

## Operational Notes

- Release migration entrypoint: `Vmemo.Release.migrate()`.
- Prefer Ash tasks (for example `mix ash.migrate`) instead of `mix ecto.*`.
- Use ISO8601 datetime strings across API/log boundaries.
