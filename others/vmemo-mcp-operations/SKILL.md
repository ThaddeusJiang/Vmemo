---
name: "vmemo"
description: "Configure Vmemo MCP in clients and operate Vmemo images through MCP tools."
---

# Vmemo MCP Operations

Use this skill when users ask to:
- configure Vmemo MCP in Cursor, Codex CLI, or other MCP clients
- debug MCP connectivity/auth issues
- use MCP tools to search or manage images

## Quick goals

1. Ensure MCP endpoint connectivity.
2. Ensure authentication works (Bearer token by default).
3. Initialize session correctly before tool calls.
4. Use image tools in a predictable order.

## Server assumptions

- Endpoint: `POST /mcp`
- Transport: Streamable HTTP
- Header auth: `Authorization: Bearer <vmemo_token>`
- Session flow required:
  1. `initialize`
  2. `notifications/initialized`
  3. `tools/list` or `tools/call`

## Client configuration checklist

1. Use the exact endpoint URL, for example `http://localhost:4000/mcp`.
2. Add `Authorization` header with Bearer token.
3. Restart client after config updates.
4. Verify tools are listed before first call.

## Cursor config example

```json
{
  "mcpServers": {
    "Vmemo": {
      "url": "http://localhost:4000/mcp",
      "headers": {
        "Authorization": "Bearer vmemo_xxx"
      }
    }
  }
}
```

## Codex CLI config example

```bash
codex mcp add vmemo \
  --url http://localhost:4000/mcp \
  --bearer-token-env-var VMEMO_MCP_TOKEN
```

## Tool usage order

1. `image_create` to create image metadata row.
2. `image_read` to fetch one image.
3. `image_update` to modify note/caption/url.
4. `image_delete` to remove an image.
5. `image_search` for retrieval and discovery.

## Troubleshooting

- `No MCP servers available`: client did not load config; verify config path and restart.
- `MCP server does not exist`: server name mismatch in client config.
- `user cancelled MCP tool call`: approval flow interrupted; retry and accept call.
- 401/403: invalid or missing bearer token.
- session errors: re-run `initialize` and include `mcp-session-id` in subsequent requests.
