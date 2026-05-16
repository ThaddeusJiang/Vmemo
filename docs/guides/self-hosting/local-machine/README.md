# Local Machine

Run Vmemo and all core dependencies on your own machine.

## Includes

- `.env.example`
- `docker-compose.yml`
- `cloudflare-tunnel-cli.md`

## Quick Start

```bash
cd docs/guides/self-hosting/local-machine
cp .env.example .env
docker compose up -d
```

## Recommended: Verify via `dev.vmemo.app`

For deployment-style verification, prefer a public hostname through Cloudflare Tunnel instead of localhost only.

1) Create a tunnel and route DNS (one-time):

```bash
cloudflared tunnel login
cloudflared tunnel create vmemo-dev
cloudflared tunnel route dns vmemo-dev dev.vmemo.app
```

2) Get token and set local env:

```bash
cd docs/guides/self-hosting/local-machine
cp .env.example .env

# Required for cloudflared service in docker compose
export CLOUDFLARED_TOKEN="$(cloudflared tunnel token vmemo-dev)"
```

Set these in `.env`:
- `PHX_HOST="dev.vmemo.app"`
- `CLOUDFLARED_TOKEN="<your token>"`

3) Start stack:

```bash
docker compose up -d
```

4) Verify:

```bash
curl -I https://dev.vmemo.app
```

Expected result:
- `200 OK` (or expected app response), not repeated redirects.

### Compose-Only Tunnel Mode (Recommended Team Default)

This project already includes a `cloudflared` service in `docker-compose.yml`.
For daily usage, you do not need to keep a separate host-level `cloudflared` process running.

Use this mode:

1) Complete one-time Cloudflare setup (login, tunnel create, DNS route).
2) Put tunnel token into `.env` as `CLOUDFLARED_TOKEN`.
3) Start everything with compose:

```bash
docker compose up -d
```

4) Check tunnel container health/logs:

```bash
docker compose ps cloudflared
docker compose logs -f cloudflared
```

If the public domain is not reachable, verify in this order:
- `docker compose ps` confirms `vmemo` and `cloudflared` are both up.
- `curl -I http://localhost:14000/` works locally.
- `docker compose logs cloudflared` has no token/auth/route errors.
- `cloudflared tunnel info <tunnel-name>` shows active connections.

## Verify

```bash
docker compose ps
docker compose logs -f
```

### SSL Redirect Regression Check (Proxy Headers)

Use these checks after deployment-related changes to ensure there is no `Plug.SSL` redirect loop behind a reverse proxy:

```bash
# 1) Baseline request
curl -i http://localhost:14000/

# 2) Simulate reverse-proxy forwarded HTTPS headers
curl -i http://localhost:14000/ \
  -H 'x-forwarded-proto: https' \
  -H 'x-forwarded-host: dev.vmemo.app' \
  -H 'x-forwarded-port: 443'
```

Expected result:
- Both requests return `200 OK`.
- The forwarded-header request should not be redirected with `301`.
- App logs should not repeatedly print `Plug.SSL is redirecting ...`.

Check `ImageMagick` inside the app container:

```bash
docker compose exec vmemo which magick
docker compose exec vmemo magick -version
```

App URL:

```text
http://localhost:14000
```

## Notes

- For this self-hosting mode, host-level `ImageMagick` is not required. The Vmemo app image already bundles `ImageMagick`.
- For detailed tunnel operations and troubleshooting, see [Cloudflare Tunnel CLI](cloudflare-tunnel-cli.md).
