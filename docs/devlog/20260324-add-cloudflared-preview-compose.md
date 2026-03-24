# Add cloudflared preview compose

## Context

`docker-compose.example.yml` only exposed Vmemo on the local Docker host. It did not show how to publish the app through Cloudflare Tunnel with the preview domain.

## Changes

- set `PHX_HOST` to `preview.vmemo.app` in `docker-compose.example.yml`
- add a `cloudflared` service using `cloudflare/cloudflared:latest`
- run the tunnel with `tunnel --no-autoupdate run`
- load `TUNNEL_TOKEN` from `.env`
- keep `TUNNEL_TOKEN` required at compose evaluation time

## Notes

This compose example assumes `preview.vmemo.app` is already configured as a public hostname for the Cloudflare Tunnel that matches `TUNNEL_TOKEN`, and that the tunnel forwards HTTP traffic to `http://vmemo:4000`.
