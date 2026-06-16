# Self-hosting Operations

Use this guide when you need to change runtime environment variables or upgrade
an existing self-hosted Vmemo server.

## Before You Start

1. Read the release notes for the target image tag.
2. Back up PostgreSQL data and the mounted `storage` directory.
3. Keep the previous working image tag available for rollback.
4. Plan a short restart window. Runtime environment changes only take effect
   after the Vmemo service restarts.

For local-machine Docker Compose deployments, one simple backup flow is:

```bash
mkdir -p backups
backup_id="$(date +%Y%m%d-%H%M%S)"

docker compose exec -T postgres pg_dump -U postgres vmemo > "backups/vmemo-${backup_id}.sql"
tar -czf "backups/storage-${backup_id}.tar.gz" vmemo_data/storage
```

For managed platforms, use the platform database backup or snapshot feature
before redeploying.

## Image Tags

Vmemo images are published to GitHub Container Registry:

```text
ghcr.io/thaddeusjiang/vmemo:stag
ghcr.io/thaddeusjiang/vmemo:<version>
```

Use a pinned version tag for production so upgrades are reproducible. Use `stag`
only when you intentionally want the latest prerelease image.

## Environment Variables

### Required Production Variables

Set these for production deployments:

```bash
PHX_SERVER=true
PHX_HOST=<public-hostname>
SECRET_KEY_BASE=<long-random-secret>
ADMIN_TOKEN=<secure-admin-token>
DATABASE_URL=postgres://USER:PASS@HOST/DATABASE
TYPESENSE_URL=http://HOST:8108
TYPESENSE_API_KEY=<typesense-api-key>
MOONDREAM_API_KEY=<moondream-api-key>
OPENROUTER_API_KEY=<openrouter-api-key>
RESEND_API_KEY=<resend-api-key>
SENTRY_DSN=<sentry-dsn>
```

Optional variables:

```bash
MOONDREAM_URL=<custom-moondream-url>
OPENROUTER_CHAT_MODEL=<openrouter-chat-model>
OPENROUTER_VISION_MODEL=<openrouter-vision-model>
SENTRY_ENV=<environment-name>
POOL_SIZE=10
ECTO_IPV6=false
DNS_CLUSTER_QUERY=
IMAGE_UPLOAD_MAX_FILE_SIZE=<bytes>
USER_DATA_IMPORT_TYPESENSE_CHUNK_SIZE=<positive-integer>
USER_DATA_IMPORT_TYPESENSE_CHUNK_PAUSE_MS=<non-negative-integer>
```

### Important Notes

- Do not rotate `SECRET_KEY_BASE` casually. Existing signed sessions and tokens
  can become invalid.
- Do not change `DATABASE_URL` or `TYPESENSE_URL` unless you are intentionally
  moving data services.
- Keep `PHX_HOST` equal to the public hostname users open in the browser.
- In the production Docker image, Nginx listens publicly on container port
  `4000`. Phoenix listens internally on `PHX_PORT`, which defaults to `4001`
  when the container starts with `start`.
- For normal Docker image deployments, leave `PHX_PORT` unset. Do not set
  `PHX_PORT=4000`, because that can make Phoenix conflict with Nginx.
- `PORT` is only a fallback when `PHX_PORT` is not set. The production entrypoint
  sets `PHX_PORT=4001` for the default Docker startup path.

## Change Environment Variables

### Docker Compose

1. Edit the deployment `.env` file.
2. Validate that required variables are still present.
3. Recreate the Vmemo service:

```bash
docker compose up -d --force-recreate vmemo
```

4. Check logs:

```bash
docker compose logs -f vmemo
```

### Single Docker Container

1. Update the env file used by `docker run --env-file`.
2. Stop the old container.
3. Start a new container with the same volumes and the updated env file:

```bash
docker run -d --name vmemo \
  -p 4000:4000 \
  --env-file .env \
  -v "$PWD/storage:/app/storage" \
  ghcr.io/thaddeusjiang/vmemo:<version>
```

### Zeabur

1. Open the Vmemo service in Zeabur.
2. Update the service environment variables.
3. Redeploy or restart the service.
4. Confirm the service still exposes port `4000`.

## Upgrade the Server

### Docker Compose

1. Choose the target image tag.
2. Update `image:` in `docker-compose.yml` if you use a pinned version.
3. Pull the target image:

```bash
docker compose pull vmemo
```

4. Recreate the Vmemo service:

```bash
docker compose up -d vmemo
```

5. Follow startup logs until migrations complete and the server starts:

```bash
docker compose logs -f vmemo
```

The production entrypoint runs database and Typesense migrations before the app
starts.

### Single Docker Container

1. Pull the target image:

```bash
docker pull ghcr.io/thaddeusjiang/vmemo:<version>
```

2. Stop and remove the old app container.
3. Start a new container with the same env file and mounted storage volume.
4. Watch logs until migrations complete.

### Zeabur

1. Update the Vmemo service image tag if the service uses a pinned tag.
2. Redeploy the service.
3. Watch deploy logs until the release migration step and app startup complete.

## Verify After Upgrade

Run these checks after every env change or server upgrade:

```bash
curl -I https://<public-hostname>/
curl http://<typesense-host>:8108/health
```

For local-machine Docker Compose deployments:

```bash
docker compose ps
docker compose logs --tail=100 vmemo
docker compose exec vmemo which magick
```

Expected result:

- Vmemo responds without redirect loops.
- PostgreSQL and Typesense are reachable.
- Logs do not show missing environment variables.
- Logs do not show failed database or Typesense migrations.
- Image upload and image viewing still work.

## Recover Typesense Store Corruption

Use this only when Typesense itself cannot start and logs an error similar to:

```text
Error while initializing store: Corruption
IO error: No such file or directory: ... /data/db/<file>.ldb
```

This means the Typesense persistent data directory is inconsistent. Restarting
the service usually keeps failing because the bad store is persisted in the
mounted `/data` volume.

Recommended recovery order:

1. If this is production and you have a Typesense volume backup, restore the
   Typesense `/data` volume from backup.
2. If this is a fresh deployment or the Typesense index can be rebuilt from
   PostgreSQL, stop Vmemo and Typelens, then clear only the Typesense volume.
3. Restart Typesense and wait for `curl http://<typesense-host>:8108/health` to
   return healthy.
4. Restart Vmemo so release migrations recreate the Typesense collections.
5. Re-sync existing records into Typesense before relying on search results.

On Zeabur, open the Typesense service, go to the Volumes tab, and delete only
the volume mounted at `/data`. This permanently clears the Typesense index. Do
not delete the PostgreSQL volume or the Vmemo `/app/storage` volume unless you
intend to remove primary data.

Typesense is a search index for Vmemo; PostgreSQL and `/app/storage` remain the
primary data stores. Clearing Typesense can recover startup, but existing images
and notes will not be searchable again until they are re-synced.

## Roll Back

1. Revert `image:` to the previous known-good tag.
2. Restore the previous env values if the failure was caused by env changes.
3. Recreate the service:

```bash
docker compose pull vmemo
docker compose up -d vmemo
docker compose logs -f vmemo
```

If the failed upgrade already ran migrations, verify the release notes before
rolling back across database changes.
