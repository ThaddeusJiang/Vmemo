# Docker Publish

This guide describes how maintainers publish Vmemo Docker images.

## Image Source of Truth

- Build source: repository root `Dockerfile`
- Runtime mode: `MIX_ENV=prod`
- Startup: release entrypoint + `bin/vmemo start`

## 1) Build Image Locally

```bash
docker build -t thaddeusjiang/vmemo:2026.4.14 .
```

## 2) Smoke Test Locally

```bash
docker run --rm -p 4000:4000 --env-file .env thaddeusjiang/vmemo:2026.4.14
```

Check logs for release migration and successful startup.

## 3) Push Image

```bash
docker push thaddeusjiang/vmemo:2026.4.14
docker tag thaddeusjiang/vmemo:2026.4.14 thaddeusjiang/vmemo:latest
docker push thaddeusjiang/vmemo:latest
```

## 4) Verify Published Tags

```bash
docker manifest inspect thaddeusjiang/vmemo:2026.4.14 >/dev/null && echo ok
docker manifest inspect thaddeusjiang/vmemo:latest >/dev/null && echo ok
```

## 5) Announce and Rollback Info

- Announce version and key changes.
- Keep previous image tag ready for rollback.
