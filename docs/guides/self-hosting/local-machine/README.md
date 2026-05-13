# Local Machine

Run Vmemo and all core dependencies on your own machine.

## Includes

- `.env.example`
- `docker-compose.yml`
- `cloudflare-tunnel-cli.md` (optional public access)

## Quick Start

```bash
cd docs/guides/self-hosting/local-machine
cp .env.example .env
docker compose up -d
```

## Verify

```bash
docker compose ps
docker compose logs -f
```

Check `ImageMagick` inside the app container:

```bash
docker compose exec vmemo which magick
docker compose exec vmemo magick -version
```

App URL:

```text
http://localhost:4000
```

## Optional

- [Cloudflare Tunnel CLI](cloudflare-tunnel-cli.md)

## Notes

- For this self-hosting mode, host-level `ImageMagick` is not required. The Vmemo app image already bundles `ImageMagick`.
