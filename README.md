# Vmemo

[![Docker Pulls](https://img.shields.io/docker/pulls/thaddeusjiang/vmemo)](https://hub.docker.com/r/thaddeusjiang/vmemo)
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

## Integrations

- Apple Shortcuts: [Setup guide](others/apple-shortcuts/README.md)
- AI app MCP: [MCP server guide](docs/features/mcp-server.md)

### MCP setup for AI apps

Vmemo exposes a Streamable HTTP MCP endpoint at `/mcp`. Use an API token from Vmemo token management as a Bearer token.

Cursor example:

```json
{
  "mcpServers": {
    "Vmemo": {
      "url": "http://localhost:4000/mcp",
      "headers": {
        "Authorization": "Bearer <VMEMO_MCP_TOKEN>"
      }
    }
  }
}
```

Codex CLI example:

```bash
export VMEMO_MCP_TOKEN="vmemo_xxx"
codex mcp add vmemo \
  --url http://localhost:4000/mcp \
  --bearer-token-env-var VMEMO_MCP_TOKEN
```

For a deployed Vmemo instance, replace `http://localhost:4000/mcp` with your public Vmemo URL, for example `https://vmemo.example.com/mcp`.

### Install the Vmemo MCP skill

Vmemo also ships an agent skill that helps AI agents configure Vmemo MCP and operate images through MCP tools.

Using the [skills CLI](https://github.com/vercel-labs/skills):

```bash
npx skills add https://github.com/ThaddeusJiang/Vmemo/tree/main/others/vmemo-mcp-operations \
  --agent codex \
  --agent cursor
```

For local development from this repository:

```bash
npx skills add ./others/vmemo-mcp-operations \
  --agent codex \
  --agent cursor
```

## One-Click Self-Hosting on Zeabur 

[![Deploy on zeabur](https://zeabur.com/button.svg)](https://zeabur.com/templates/H3EL85)

More self-hosting [docs](docs/guides/self-hosting/README.md)

## Documentation

- [Contributor guides](docs/guides/development/README.md)

## Author

Created and maintained by [Thaddeus Jiang](https://github.com/ThaddeusJiang).
