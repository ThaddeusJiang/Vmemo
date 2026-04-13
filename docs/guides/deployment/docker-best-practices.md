# Docker Best Practices

This document describes the recommended release startup approach for Vmemo Docker deployment, with focus on migration and startup order.

## Core Principles

1. Use a single production Dockerfile.
2. Start with Elixir release (`bin/vmemo start`).
3. Run unified release migration at entrypoint (Postgres + Typesense).

## Entrypoint Script

[`rel/entrypoint.sh`](/Users/amami/git/my-personal-2026/Vmemo/rel/entrypoint.sh):

```bash
/app/bin/vmemo eval "Vmemo.Release.migrate()"
exec /app/bin/vmemo "$@"
```

Notes:

- Exit immediately on migration failure to avoid partial startup states.
- Main process should always be the release command (`start` by default).

## Dockerfile Pattern

```dockerfile
RUN mix release

COPY --from=builder /app/_build/prod/rel/vmemo /app

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["start"]
```

## Example Usage

```bash
docker run -p 4000:4000 \
  -e DATABASE_URL=postgresql://user:pass@host:port/database \
  -e SECRET_KEY_BASE=your_secret_key_base \
  -e ADMIN_PASSWORD=your_admin_password \
  -e RESEND_API_KEY=your_resend_key \
  -e TYPESENSE_URL=http://typesense:8108 \
  -e TYPESENSE_API_KEY=your_typesense_key \
  -e OPENROUTER_API_KEY=your_openrouter_key \
  -e MOONDREAM_API_KEY=your_moondream_key \
  -e SENTRY_DSN=your_sentry_dsn \
  -e PHX_SERVER=true \
  vmemo:latest
```

Container startup sequence:

1. `bin/vmemo eval "Vmemo.Release.migrate()"`
2. `bin/vmemo start`

## Manual Operations

Run migration manually:

```bash
docker run --rm \
  -e DATABASE_URL=postgresql://user:pass@host/database \
  vmemo:latest \
  eval "Vmemo.Release.migrate()"
```

Run interactive debugging:

```bash
docker run --rm -it \
  -e DATABASE_URL=postgresql://user:pass@host/database \
  --entrypoint /bin/bash \
  vmemo:latest
```

## References

- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Phoenix Deployment Guide](https://hexdocs.pm/phoenix/deployment.html)
