# Create cloudflare preview tunnel

## Context

The local machine needed a real Cloudflare Tunnel for the preview deployment example. The compose file already expected a `TUNNEL_TOKEN`, but the tunnel and DNS route did not exist yet.

## Changes

- installed `cloudflared` on the local machine
- authenticated `cloudflared` with Cloudflare
- created a named tunnel: `vmemo-preview`
- added the DNS route for `preview.vmemo.app`
- updated local `.env` with the generated `TUNNEL_TOKEN`

## Result

`preview.vmemo.app` now points to the `vmemo-preview` tunnel, and the local compose configuration has the tunnel token required to run the `cloudflared` sidecar.
