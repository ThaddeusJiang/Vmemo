# Vmemo

[![Container Image](https://img.shields.io/badge/container-ghcr.io%2Fthaddeusjiang%2Fvmemo-blue)](https://github.com/ThaddeusJiang/Vmemo/pkgs/container/vmemo)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](https://github.com/ThaddeusJiang/Vmemo/blob/main/LICENSE)

Vmemo is a visual memo app for capturing life with images, searching with AI, and reviewing moments quickly without writing long text notes.

## Why Vmemo

For people who think and remember visually, image notes can be much more effective than text-only notes:

- Visual notes strengthen long-term memory and make recall more vivid by helping you reconstruct the original scene and context.
- A single image can express what is hard to put into words; when you do not know how to describe an idea, just upload an image and let AI extract key information automatically.

## Features

- Photo upload and management (multi-upload, drag-and-drop, paste).
- AI-powered search (text and image similarity).
- AI caption and OCR extraction.
- API token management.
- REST API for external integrations.
- Responsive web UI for desktop and mobile.

## Install Vmemo

### Option 1: One-Click Self-Hosting on Zeabur

[![Deploy on zeabur](https://zeabur.com/button.svg)](https://zeabur.com/templates/H3EL85)

### Option 2: Local Machine / Self-Hosting

#### Docker Compose

```bash
cd docs/guides/self-hosting/local-machine
cp .env.example .env
docker compose up -d
```

Open:

```text
http://localhost:14000
```

Check Typesense health:

```bash
curl http://localhost:18108/health
```

#### Docker

Use the published GHCR image when you already have PostgreSQL, Typesense, and required environment variables configured:

```bash
docker run --rm -p 4000:4000 \
  --env-file .env \
  ghcr.io/thaddeusjiang/vmemo:latest
```

Image tags:

```text
ghcr.io/thaddeusjiang/vmemo:latest
ghcr.io/thaddeusjiang/vmemo:stag
ghcr.io/thaddeusjiang/vmemo:<version>
```

## Integrations

- Apple Shortcuts: [Setup guide](others/apple-shortcuts/README.md)
- AI agent skill: [Setup guide](skills/README.md)

## Documentation

- [Self-hosting docs](docs/guides/self-hosting/README.md)
- [Contributor guides](docs/guides/development/README.md)

## Author

Created and maintained by [Thaddeus Jiang](https://github.com/ThaddeusJiang).
