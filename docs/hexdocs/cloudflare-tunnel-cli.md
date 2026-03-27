# Cloudflare Tunnel Complete CLI Guide

This guide covers the full Cloudflare Tunnel workflow with `cloudflared` CLI on macOS, from installation to long-running process, using `vmemo.app` as the example domain.

Use your own values consistently:

- `<tunnel-name>` example: `air`
- `<public-hostname>` example: `dev.vmemo.app`
- `<origin-url>` example: `http://localhost:4000`

## Quick Start (for this project)

If you only need a working dev route to local Vmemo:

1. Create tunnel: `cloudflared tunnel create air`
2. Route host: `cloudflared tunnel route dns air dev.vmemo.app`
3. Set ingress target in `~/.cloudflared/config.yml` to `http://localhost:4000`
4. Run in background: `nohup cloudflared tunnel run --token "$(cloudflared tunnel token air)" > /tmp/cloudflared-air.log 2>&1 &`
5. Open `https://dev.vmemo.app`

## Prerequisites

- Cloudflare account with permission to manage the `vmemo.app` zone
- Vmemo is reachable from the tunnel machine
  - Local host example: `http://localhost:4000`
  - Same Docker network example: `http://vmemo:4000`

## 1) Install cloudflared

### macOS

```bash
brew install cloudflared
```

Check install:

```bash
cloudflared --version
```

## 2) Authenticate with Cloudflare

```bash
cloudflared tunnel login
```

This opens a browser to authorize `cloudflared` and select your zone.

## 3) Create tunnel

```bash
cloudflared tunnel create <tunnel-name>
```

Useful inspection commands:

```bash
cloudflared tunnel list
cloudflared tunnel info <tunnel-name>
```

The create command writes credentials to a local JSON file under `~/.cloudflared/`.

## 4) Create DNS routes for hostnames

```bash
cloudflared tunnel route dns <tunnel-name> <public-hostname>
```

If you need multiple hostnames, add one route command per hostname.

## 5) Create local config file

Create `~/.cloudflared/config.yml`:

```yaml
tunnel: <tunnel-name>
credentials-file: /Users/<your-user>/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: <public-hostname>
    service: <origin-url>
  - service: http_status:404
```

Replace:

- `<your-user>` with your OS username
- `<tunnel-id>` with the real tunnel ID from `cloudflared tunnel list`
- `<public-hostname>` with your real domain, for example `dev.vmemo.app`
- `<origin-url>` with your Vmemo origin, for example `http://localhost:4000`

Validate config before running:

```bash
cloudflared tunnel ingress validate
```

## 6) Start tunnel

Foreground run (first-time verification):

```bash
cloudflared tunnel run <tunnel-name>
```

Background run on macOS (recommended for local development):

```bash
nohup cloudflared tunnel run --token "$(cloudflared tunnel token <tunnel-name>)" > /tmp/cloudflared-<tunnel-name>.log 2>&1 &
```

## 7) Configure Vmemo public host

Set Vmemo host to the same public domain:

```bash
PHX_HOST=<public-hostname>
```

Restart Vmemo after updating env so generated URLs and host checks align with the tunnel domain.

## 8) Verify end-to-end

Check origin first (must return `200` or expected app response):

```bash
curl -I http://localhost:4000
```

Check tunnel state:

```bash
cloudflared tunnel info <tunnel-name>
```

Check app path:

```bash
curl -I https://<public-hostname>
```

Manual checks:

- Open `https://<public-hostname>`
- Confirm pages and static assets load
- Confirm login and API paths are reachable

## 9) Operations and troubleshooting

Stop a background run:

```bash
pkill -f "cloudflared tunnel run --token"
```

View background log:

```bash
tail -f /tmp/cloudflared-<tunnel-name>.log
```

Common issues:

- `502` or `503` from edge: ingress `service` target is wrong, or app is not listening on the target port
- Host mismatch behavior: `PHX_HOST` does not match public hostname
- Route missing: run `cloudflared tunnel route dns ...` again for target hostname
- Invalid credentials path: `credentials-file` points to wrong JSON file

## Optional: clean up and re-create

```bash
cloudflared tunnel delete <tunnel-name>
```

If a tunnel was created with a wrong name or route, deleting and re-creating is usually faster than editing multiple pieces manually.
