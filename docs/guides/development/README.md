# Development

- [Setup](setup.md)
- [FAQ](faq.md)
- [Tidewave](tidewave.md)
- [Resource Diagrams](resource-diagrams.md)
- [Project Specs](project-specs.md)
- [Oban Queue Design](oban-queue-design.md)
- [Coding Guidelines](../coding/README.md)

## Direct Links

- [Elixir](../coding/elixir.md)

## Docker

- Dev dependencies: use root `docker-compose.yml` via `docker compose up -d`. See [Setup](setup.md).
- Production-like local run and image publish: see `docs/guides/deployment/docker.md`.
- One-machine self-hosting: use `docs/guides/self-hosting/local-machine/docker-compose.yml`. See `docs/guides/self-hosting/local-machine/README.md`.
- Canonical rules:
  - Root `Dockerfile` is the only production image source.
  - Do not maintain a separate development Dockerfile.
  - Root `docker-compose.yml` is for development dependencies.
