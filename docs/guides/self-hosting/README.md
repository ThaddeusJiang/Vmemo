# Self-hosting

## Directory Layout

```text
docs/guides/self-hosting/
├── local-machine/
│   ├── README.md
│   ├── .env.example
│   ├── docker-compose.yml
│   └── cloudflare-tunnel-cli.md
├── zeabur/
│   ├── README.md
│   └── vmemo.yml
└── fly/
    ├── README.md
    └── .env.example
```

## Dependency Matrix

| Mode | Vmemo App | PostgreSQL | Typesense | Moondream |
| --- | --- | --- | --- | --- |
| Local machine | self-hosted | self-hosted | self-hosted | self-hosted (`moondream-station`) |
| Zeabur | self-hosted | self-hosted (Zeabur service) | self-hosted (Zeabur service) | managed service (`moondream.ai`) |
| Fly.io | self-hosted | managed service | managed service | managed service (`moondream.ai`) |

## Mode Guides

- [Local Machine](local-machine/README.md)
- [Zeabur](zeabur/README.md)
- [Fly.io](fly/README.md)
