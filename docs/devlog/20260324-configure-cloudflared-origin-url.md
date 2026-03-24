# Configure cloudflared origin url

## Context

The Cloudflare Tunnel connected successfully, but it still returned `503` because no ingress rule or origin URL was provided to `cloudflared`.

## Changes

- updated the preview `cloudflared` command to run with `--url http://vmemo:4000`
- applied the same origin URL setting to `_local/docker-compose.yml`

## Result

The preview tunnel now forwards HTTP traffic to the Vmemo container instead of returning the default `503` response.
