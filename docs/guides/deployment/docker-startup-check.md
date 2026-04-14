# Docker Startup Checklist

This document lists the configuration checks required before container startup (release mode).

## Current Startup Chain

### 1. Entrypoint Script (`rel/entrypoint.sh`)

- Container runs pre-start preparation via `ENTRYPOINT`.
- Startup runs unified release migration (`bin/vmemo eval "Vmemo.Release.migrate()"`, including Postgres + Typesense).
- Release starts via `CMD` (`bin/vmemo start`).

### 2. Dockerfile Configuration

- Builder runs `mix release`.
- Runner copies release artifacts only.
- Uses `ENTRYPOINT + CMD`, with `CMD ["start"]`.

### 3. Zeabur Config (`docs/guides/self-hosting/zeabur/vmemo.yml`)

- Includes `PHX_SERVER=true`.
- Includes `ADMIN_PASSWORD`.
- Keeps other required envs (`SECRET_KEY_BASE`, `RESEND_API_KEY`, etc.).
- Includes `SENTRY_DSN`.

## Required Environment Variables

1. `SECRET_KEY_BASE`
2. `ADMIN_PASSWORD`
3. `RESEND_API_KEY`
4. `DATABASE_URL`
5. `TYPESENSE_URL`
6. `TYPESENSE_API_KEY`
7. `MOONDREAM_API_KEY`
8. `OPENROUTER_API_KEY`
9. `SENTRY_DSN`

Optional: `MOONDREAM_URL`, `SENTRY_ENV`

## Startup Verification

1. **Run release migration (Postgres + Typesense)**

```bash
bin/vmemo eval "Vmemo.Release.migrate()"
```

2. **Start service**

```bash
bin/vmemo start
```

## Troubleshooting

### Migration Failure

1. Check container logs: `docker logs <container_id>`
2. Verify database and Typesense connectivity
3. Verify `TYPESENSE_URL` / `TYPESENSE_API_KEY`

### Missing Environment Variables

1. Verify required keys against `config/runtime.exs`
2. Verify variable names are spelled correctly

## Validation Checklist

- [ ] `rel/entrypoint.sh` exists and is executable
- [ ] Dockerfile starts via release (`CMD ["start"]`)
- [ ] Zeabur config contains required envs
- [ ] Database service is reachable
- [ ] Typesense service is reachable
