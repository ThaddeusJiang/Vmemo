## Update vmemo template

[![Deploy on Zeabur](https://zeabur.com/button.svg)](https://zeabur.com/templates/H3EL85)

```sh
npx zeabur template update -c H3EL85 -f vmemo.yml
```

## Template Notes

- `vmemo.yml` is the only Zeabur template kept in this repo
- The template includes all required dependencies: `postgresql` and `typesense`
- The app service uses the project `Dockerfile`
- Container startup uses `rel/entrypoint.sh`
- `ENTRYPOINT` runs release migration tasks
- `CMD` runs `start` (resolved to `bin/vmemo start`)
- `PHX_SERVER=true` must be set
- `DATABASE_URL`, `SECRET_KEY_BASE`, `ADMIN_TOKEN`, `SENTRY_DSN`, `RESEND_API_KEY`, `TYPESENSE_URL`, `TYPESENSE_API_KEY`, and `MOONDREAM_URL` are required
- `OPENROUTER_API_KEY` is optional
- `ADMIN_TOKEN` must be provided explicitly and should not rely on template placeholder defaults
- Typesense access should expose the API key only when the template needs real external access
- Template configuration should not expose secrets in instructions or logs

## Zeabur Deploy Checklist

The checklist below applies to Vmemo deployment and release on Zeabur.

### 1. Code and Branch

- [ ] Confirm the target branch, usually `main`, already contains the required changes
- [ ] Confirm `mix.exs` and `mix.lock` are in sync
- [ ] Confirm there are no uncommitted critical changes, especially runtime config changes

### 2. Build and Runtime

- [ ] Zeabur builds from the project `Dockerfile`
- [ ] The entrypoint is `rel/entrypoint.sh`
- [ ] `assets.deploy` runs during image build
- [ ] `PHX_SERVER=true` is set

### 3. Required Runtime Env Vars

These must all be set, otherwise container startup will exit early:

- [ ] `DATABASE_URL`
- [ ] `SECRET_KEY_BASE`
- [ ] `ADMIN_TOKEN`
- [ ] `SENTRY_DSN`
- [ ] `RESEND_API_KEY`
- [ ] `TYPESENSE_URL`
- [ ] `TYPESENSE_API_KEY`
- [ ] `MOONDREAM_URL`

Optional, missing values only cause warnings:

- [ ] `OPENROUTER_API_KEY`

### 4. Phoenix Runtime Config

- [ ] `PHX_HOST` matches the real domain, for example `vmemo.app`
- [ ] `PORT` is injected by Zeabur or explicitly set, default `4000`
- [ ] Set `ECTO_IPV6=true` if IPv6 is required

### 5. Dependency Checks

- [ ] PostgreSQL is reachable through `DATABASE_URL`
- [ ] Typesense is reachable through `TYPESENSE_URL` and `TYPESENSE_API_KEY`
- [ ] Moondream is reachable through `MOONDREAM_URL`
- [ ] Resend API key is valid for email delivery
- [ ] Sentry DSN is valid for error reporting

### 6. Zeabur Service Settings

- [ ] Service port matches `PORT`
- [ ] Healthcheck points to the app port and returns `200` or `302`
- [ ] Logs show `PORT=...` and `PHX_HOST=...`

### 7. Post Deploy Verification

- [ ] Homepage is reachable and renders correctly
- [ ] Login works
- [ ] Image upload works
- [ ] Typesense search returns newly created data
- [ ] Oban jobs run without persistent failures
- [ ] Sentry receives at least one validation event

### 8. Rollback Prep

- [ ] The previous deployment version or image tag is recorded
- [ ] Any database change has a rollback or remediation plan

## Troubleshooting

### Startup Flow

1. `bin/vmemo eval "Vmemo.Release.migrate()"`
2. `bin/vmemo start`

`Vmemo.Release.migrate()` includes both AshPostgres repo migrations and Typesense migrations.

### Migration Failure

- Check container logs first
- Verify database permissions and connectivity
- Verify `TYPESENSE_URL` and `TYPESENSE_API_KEY`
- Confirm required env vars are set exactly as expected

### Validation

```sh
docker logs <container_id>
docker exec -it <container_id> /bin/bash
/app/bin/vmemo eval "Vmemo.Release.migrate()"
```
