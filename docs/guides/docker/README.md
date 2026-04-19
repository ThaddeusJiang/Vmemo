# Docker Guide

This is the single entry point for Docker and Docker Compose usage in Vmemo.

## Choose By Scenario

| Scenario | Main Doc | Compose File | Notes |
| --- | --- | --- | --- |
| Local development dependencies (Postgres + Typesense) | `docs/guides/development/setup.md` | `docker-compose.yml` (repo root) | Use `docker compose up -d` |
| Local production-like app run (maintainers) | `docs/guides/deployment/docker.md#run-locally-production-like` | `docker-compose.yml` (repo root, deps only) | Build image from root `Dockerfile` |
| Docker image publishing (maintainers) | `docs/guides/deployment/docker.md#publish-images` | N/A | Push to Docker Hub |
| Release startup / migration checks | `docs/guides/deployment/docker.md#startup-checklist` | N/A | Validate entrypoint + runtime env |
| Runtime conventions / best practices | `docs/guides/deployment/docker.md#best-practices` | N/A | Single production-image policy |
| Self-hosting on one machine | `docs/guides/self-hosting/local-machine/README.md` | `docs/guides/self-hosting/local-machine/docker-compose.yml` | Full stack in one compose file |
| E2E CI compose stack | `.github/workflows/e2e-tests.yml` | `docker-compose.e2e.yml` (repo root) | CI-only stack |

## Canonical Rules

- Use the repository root `Dockerfile` as the only production-image source.
- Do not maintain a separate development Dockerfile path.
- Use root `docker-compose.yml` for development dependencies.
- Use `docs/guides/self-hosting/local-machine/docker-compose.yml` for one-machine self-hosting.

## Quick Commands

### Dev dependencies

```bash
docker compose up -d
```

### Local production-like run

```bash
docker build -t vmemo:local .
docker run --rm -p 4000:4000 --env-file .env vmemo:local
```

### Self-hosting local-machine profile

```bash
cd docs/guides/self-hosting/local-machine
cp .env.example .env
docker compose up -d
```

## Notes

- If a Docker-related doc conflicts with this page's routing, follow this page first, then the scenario-specific doc.
