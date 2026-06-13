# Docker Deployment (Maintainers)

This is the single Docker document under `docs/guides/deployment`.

## Scope

- Maintainer-oriented Docker image policy
- Release startup checks
- Runtime best practices

## Quick Navigation

- User-facing Docker start commands: [README](../../../README.md#install-vmemo)
- Startup checks: [Startup Checklist](#startup-checklist)
- Runtime conventions: [Best Practices](#best-practices)

## Canonical Policy

- Use the repository root `Dockerfile` as the only production image source.
- Build and run with `MIX_ENV=prod`.
- Do not maintain a separate development Dockerfile workflow.
- Root `docker-compose.yml` is for local dependency services.

Release startup behavior:

1. `bin/vmemo eval "Vmemo.Release.migrate()"`
2. `bin/vmemo start`

Remote IEx:

```bash
docker ps --format '{{.Names}}'
docker exec -it <container_name> /app/bin/vmemo remote
```

## Startup Checklist

### Entrypoint and Dockerfile

- `rel/entrypoint.sh` exists and is executable.
- Entrypoint runs `bin/vmemo eval "Vmemo.Release.migrate()"`.
- Dockerfile runner starts via `ENTRYPOINT + CMD ["start"]`.
- Dockerfile runner includes ImageMagick (`magick`) for AI vision request preprocessing.

### Required Environment Variables

1. `SECRET_KEY_BASE`
2. `ADMIN_TOKEN`
3. `RESEND_API_KEY`
4. `DATABASE_URL`
5. `TYPESENSE_URL`
6. `TYPESENSE_API_KEY`
7. `MOONDREAM_API_KEY`
8. `OPENROUTER_API_KEY`
9. `SENTRY_DSN`

Optional: `MOONDREAM_URL`, `OPENROUTER_VISION_MODEL`, `SENTRY_ENV`

### Troubleshooting

Migration failure:

1. Check logs: `docker logs <container_id>`
2. Verify DB and Typesense connectivity
3. Verify `TYPESENSE_URL` and `TYPESENSE_API_KEY`

Missing environment variables:

1. Verify keys against `config/runtime.exs`
2. Verify key names and values

Image preprocessing unavailable:

1. Enter container shell and check tool existence: `which magick`
2. Verify version: `magick -version`
3. Rebuild image from root `Dockerfile` if tool is missing.

## Best Practices

1. Keep a single production image path.
2. Fail fast if migration fails before app startup.
3. Keep release process deterministic and reproducible.
4. Keep previous stable tag available for rollback.

## Related

- Release flow: `docs/guides/development/release.md`
- Cross-section Docker entry: `docs/guides/docker/README.md`
