# Publish application via cloudflared cli

This guide uses Cloudflare Tunnel with `cloudflared` CLI on macOS, without `~/.cloudflared/config.yml`, using `vmemo.app` as the example domain.

Use your own values consistently:

- `<tunnel-name>` example: `air`
- `<public-hostname>` example: `preview.vmemo.app`
- `<origin-url>` example: `http://localhost:4000`

## Quick Start (for this project)

If you only need a working route to local Vmemo:

1. Create tunnel: `cloudflared tunnel create air`
2. Route host: `cloudflared tunnel route dns air preview.vmemo.app`
3. Run in background with `--url`: `nohup cloudflared tunnel --no-autoupdate --url http://localhost:4000 run --token "$(cloudflared tunnel token air)" > /tmp/cloudflared-air.log 2>&1 &`
4. Open `https://preview.vmemo.app`

## Prerequisites

- Cloudflare account with permission to manage the `vmemo.app` zone
- Vmemo is reachable from the tunnel machine
  - Local host example: `http://localhost:4000`
  - Docker host port example: `http://localhost:14000`

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

## 4) Create DNS route for hostname

```bash
cloudflared tunnel route dns <tunnel-name> <public-hostname>
```

If you need multiple hostnames, add one route command per hostname.

## 5) Start tunnel with --url

Foreground run (first-time verification):

```bash
cloudflared tunnel --no-autoupdate --url <origin-url> run --token "$(cloudflared tunnel token <tunnel-name>)"
```

Background run on macOS (recommended for local development):

```bash
nohup cloudflared tunnel --no-autoupdate --url <origin-url> run --token "$(cloudflared tunnel token <tunnel-name>)" > /tmp/cloudflared-<tunnel-name>.log 2>&1 &
```

This route does not require `~/.cloudflared/config.yml`.

## 6) Configure Vmemo public host

Set Vmemo host to the same public domain:

```bash
PHX_HOST=<public-hostname>
```

Restart Vmemo after updating env so generated URLs and host checks align with the tunnel domain.

## 7) Verify end-to-end

Check origin first (must return `200` or expected app response):

```bash
curl -I <origin-url>
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

## 8) Operations and troubleshooting

Stop a background run:

```bash
pkill -f "cloudflared tunnel --no-autoupdate --url"
```

View background log:

```bash
tail -f /tmp/cloudflared-<tunnel-name>.log
```

Common issues:

- `502` or `503` from edge: `--url` target is wrong, or app is not listening on the target port
- Host mismatch behavior: `PHX_HOST` does not match public hostname
- Route missing: run `cloudflared tunnel route dns ...` again for target hostname
- Tunnel token mismatch: regenerate token via `cloudflared tunnel token <tunnel-name>`

## Optional: clean up and re-create

```bash
cloudflared tunnel delete <tunnel-name>
```

If a tunnel was created with a wrong name or route, deleting and re-creating is usually faster than editing multiple pieces manually.
