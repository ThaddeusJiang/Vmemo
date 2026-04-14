# Self-hosting (For Users)

This section is for users who deploy and run Vmemo.

## Directory Layout

```text
docs/guides/self-hosting/
├── local-machine/
│   ├── .env.example
│   └── docker-compose.yml
├── zeabur/
│   ├── .env.example
│   ├── vmemo.yml
│   └── README.md
├── fly/
│   └── .env.example
└── cloudflare-tunnel-cli.md
```

## Dependency Matrix

| Mode | Vmemo App | PostgreSQL | Typesense | Moondream |
| --- | --- | --- | --- | --- |
| Local machine | self-hosted | self-hosted | self-hosted | self-hosted (`moondream-station`) |
| Zeabur | self-hosted | self-hosted (Zeabur service) | self-hosted (Zeabur service) | managed service (`moondream.ai`) |
| Fly.io | self-hosted | managed service | managed service | managed service (`moondream.ai`) |

## Quick Start by Mode

### Local machine

```bash
cd docs/guides/self-hosting/local-machine
cp .env.example .env
docker compose up -d
```

### Zeabur

```bash
cd docs/guides/self-hosting/zeabur
cp .env.example .env
```

### Fly.io

```bash
cd docs/guides/self-hosting/fly
cp .env.example .env
```

## Additional Guide

- [Cloudflare Tunnel CLI](cloudflare-tunnel-cli.md)
