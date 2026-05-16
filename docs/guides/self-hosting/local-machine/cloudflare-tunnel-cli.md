# Publish application via cloudflared cli

This guide uses Cloudflare Tunnel with `cloudflared` CLI on macOS, without `~/.cloudflared/config.yml`, using `vmemo.app` as the example domain.

Use your own values consistently:

- `<tunnel-name>` example: `vmemo-dev`
- `<public-hostname>` example: `dev.vmemo.app`
- `<origin-url>` example: `http://localhost:14000`

## Quick Start (for this project)

If you only need a working route to local Vmemo:

1. Create tunnel: `cloudflared tunnel create vmemo-dev`
2. Route host: `cloudflared tunnel route dns vmemo-dev dev.vmemo.app`
3. Run in background with `--url`: `nohup cloudflared tunnel --no-autoupdate --url http://localhost:14000 run --token "$(cloudflared tunnel token vmemo-dev)" > /tmp/cloudflared-vmemo-dev.log 2>&1 &`
4. Open `https://dev.vmemo.app`

## Prerequisites

- Cloudflare account with permission to manage the `vmemo.app` zone
- Vmemo is reachable from the tunnel machine
  - Local host example: `http://localhost:14000`
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

If a hostname already points to the wrong tunnel and you need to force switch:

```bash
cloudflared tunnel route dns --overwrite-dns <tunnel-name> <public-hostname>
```

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

If you already have `~/.cloudflared/config.yml` and want token+url mode to ignore it, use:

```bash
cloudflared --config /dev/null tunnel --no-autoupdate --url <origin-url> run --token "$(cloudflared --config /dev/null tunnel token <tunnel-name>)"
```

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

- `1033` tunnel error: hostname is mapped, but the mapped tunnel has no active connector.
  - Check `cloudflared tunnel list` and ensure the target tunnel has non-empty `CONNECTIONS`.
  - Start a connector: `nohup cloudflared tunnel --no-autoupdate run <tunnel-name> > /tmp/cloudflared-<tunnel-name>.log 2>&1 &`
- `502` or `503` from edge: `--url` target is wrong, or app is not listening on the target port
- Host mismatch behavior: `PHX_HOST` does not match public hostname
- Route missing: run `cloudflared tunnel route dns ...` again for target hostname
- Existing local config hijacks commands: if commands behave as if using another tunnel, rerun with `--config /dev/null`
- Tunnel token mismatch: regenerate token via `cloudflared tunnel token <tunnel-name>`

## Optional: clean up and re-create

```bash
cloudflared tunnel delete <tunnel-name>
```

If a tunnel was created with a wrong name or route, deleting and re-creating is usually faster than editing multiple pieces manually.
