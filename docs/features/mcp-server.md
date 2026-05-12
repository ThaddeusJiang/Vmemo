# MCP Server

## Overview

Vmemo exposes an [MCP (Model Context Protocol)](https://modelcontextprotocol.io/) server for LLM tool use. This allows AI assistants and agents to search images and read image data through the standard MCP protocol.

- Endpoint: `POST /mcp`
- Protocol version: `2024-11-05`
- Transport: StreamableHttp only (no SSE/GET)
- Authentication: Optional Bearer token

## Authentication

MCP supports optional Bearer token authentication. Authenticated sessions can access user-scoped data; unauthenticated sessions have limited access.

```http
Authorization: Bearer vmemo_your_token_here
```

Create tokens at `/tokens` in the Vmemo web app. See [API Token](api-tokens.md) for details.

## Session Lifecycle

### 1. Initialize

```bash
curl -X POST https://your-domain.com/mcp \
  -H "Authorization: Bearer vmemo_your_token" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": {
      "protocolVersion": "2024-11-05",
      "capabilities": {},
      "clientInfo": {
        "name": "my-client",
        "version": "1.0.0"
      }
    }
  }'
```

Response:

```json
{
  "id": 1,
  "jsonrpc": "2.0",
  "result": {
    "capabilities": {
      "resources": {},
      "tools": { "listChanged": false }
    },
    "protocolVersion": "2024-11-05",
    "serverInfo": {
      "name": "MCP Server",
      "version": "0.1.0"
    }
  }
}
```

The response includes a `mcp-session-id` header. Include it in all subsequent requests:

```http
mcp-session-id: <session-id>
```

### 2. Send Initialized Notification

```json
{
  "jsonrpc": "2.0",
  "method": "notifications/initialized"
}
```

### 3. Use Tools and Resources

After initialization, you can list/call tools and read resources.

## Tools

### image_search

Search for images by text query or find similar images.

**List tools:**

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/list",
  "params": {}
}
```

**Call image_search:**

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "image_search",
    "arguments": {
      "input": {
        "query": "Wall-E robot",
        "page": 1
      }
    }
  }
}
```

Input arguments:

| Name | Type | Required | Description |
|---|---|---|---|
| `query` | string | No | Text search query (searches note and caption fields) |
| `similar_image_id` | string | No | UUID of image to find similar images for |
| `page` | integer | No | Page number for pagination (default: 1) |

Response:

```json
{
  "id": 3,
  "jsonrpc": "2.0",
  "result": {
    "content": [
      {
        "text": "[{\"id\":\"e1015cc4-245c-47b9-a86f-50d8874652d0\",\"url\":\"http://localhost:4000/storage/v1/.../image.png\",\"note\":\"Wall-E sign\",\"caption\":\"A sign with Wall-E artwork\",\"resource_uri\":\"vmemo://image/image\",\"resource_params\":{\"id\":\"e1015cc4-245c-47b9-a86f-50d8874652d0\"},\"html_uri\":\"vmemo://image/html\",\"html_params\":{\"id\":\"e1015cc4-245c-47b9-a86f-50d8874652d0\"},\"url_uri\":\"vmemo://image/url\",\"url_params\":{\"id\":\"e1015cc4-245c-47b9-a86f-50d8874652d0\"}}]",
        "type": "text"
      }
    ],
    "isError": false
  }
}
```

`image_search` returns lightweight result metadata. Use `resource_uri` and `resource_params` with `resources/read` to lazily load image data only when a client needs the actual image bytes.

Search behavior:
- Text query only: full-text search on `note` and `caption` fields, falls back to semantic (vector) search if no text matches
- `similar_image_id` only: pure vector similarity search
- Both: combined text scoring + semantic similarity
- Neither: returns paginated library images (newest first)

### image_create

Create an image record for the authenticated user.

Input arguments:

| Name | Type | Required | Description |
|---|---|---|---|
| `file` | string | Yes | Data URL payload: `data:image/...;base64,...` |
| `note` | string | No | Note text |
| `caption` | string | No | Caption text |

`image_create` uploads image content via `file`.

### image_read

Read one image by ID.

Input arguments:

| Name | Type | Required | Description |
|---|---|---|---|
| `id` | string (UUID) | Yes | Image ID |

### image_update

Update one image by ID.

Input arguments:

| Name | Type | Required | Description |
|---|---|---|---|
| `id` | string (UUID) | Yes | Image ID |
| `note` | string | No | Updated note |
| `caption` | string | No | Updated caption |

At least one of `note`, `caption` must be provided.

### image_delete

Delete one image by ID.

Input arguments:

| Name | Type | Required | Description |
|---|---|---|---|
| `id` | string (UUID) | Yes | Image ID |

## Resources

Vmemo exposes three MCP resources for image data. Each uses a URI template with an image ID.

**List resources:**

```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "method": "resources/list",
  "params": {}
}
```

### image_url

Get the URL of an image.

- URI: `vmemo://image/url`
- Required read param: `id`
- MIME type: `text/plain`

### image_html

Get an image rendered as HTML with caption and note.

- URI: `vmemo://image/html`
- Required read param: `id`
- MIME type: `text/html`
- Returns: `<div class="image-card"><img src="..."/><p class="image-caption">...</p><p class="image-note">...</p></div>`

### image_data

Get the image as a base64-encoded data URL.

- URI: `vmemo://image/image`
- Required read param: `id`
- MIME type: auto-detected (`image/jpeg`, `image/png`, `image/gif`, `image/webp`)
- Returns: `data:image/{type};base64,{base64-data}`

**Read a resource:**

```json
{
  "jsonrpc": "2.0",
  "id": 5,
  "method": "resources/read",
  "params": {
    "uri": "vmemo://image/url",
    "id": "e1015cc4-245c-47b9-a86f-50d8874652d0"
  }
}
```

Vmemo uses stable resource URIs plus an `id` read parameter so the resource works with AshAi's exact URI matching.

## Full Example Session

```bash
# 1. Initialize session and capture session ID
SESSION_ID=$(curl -s -D - -X POST https://your-domain.com/mcp \
  -H "Authorization: Bearer vmemo_your_token" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"my-client","version":"1.0"}}}' \
  2>/dev/null | grep -i 'mcp-session-id' | awk '{print $2}' | tr -d '\r')

# 2. Send initialized notification
curl -s -X POST https://your-domain.com/mcp \
  -H "Authorization: Bearer vmemo_your_token" \
  -H "Content-Type: application/json" \
  -H "mcp-session-id: $SESSION_ID" \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized"}'

# 3. Search for images
curl -s -X POST https://your-domain.com/mcp \
  -H "Authorization: Bearer vmemo_your_token" \
  -H "Content-Type: application/json" \
  -H "mcp-session-id: $SESSION_ID" \
  -d '{
    "jsonrpc":"2.0","id":3,"method":"tools/call","params":{
      "name":"image_search",
      "arguments":{"input":{"query":"sunset beach"}}
    }
  }'
```

## Connecting from MCP Clients

### Claude Desktop

Add to `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "vmemo": {
      "url": "https://your-domain.com/mcp",
      "headers": {
        "Authorization": "Bearer vmemo_your_token"
      }
    }
  }
}
```

### Programmatic (Python)

```python
import httpx
import json

BASE = "https://your-domain.com/mcp"
HEADERS = {
    "Authorization": "Bearer vmemo_your_token",
    "Content-Type": "application/json"
}

# Initialize
resp = httpx.post(BASE, headers=HEADERS, json={
    "jsonrpc": "2.0", "id": 1,
    "method": "initialize",
    "params": {
        "protocolVersion": "2024-11-05",
        "capabilities": {},
        "clientInfo": {"name": "python-client", "version": "1.0"}
    }
})
session_id = resp.headers["mcp-session-id"]
HEADERS["mcp-session-id"] = session_id

# Search images
resp = httpx.post(BASE, headers=HEADERS, json={
    "jsonrpc": "2.0", "id": 2,
    "method": "tools/call",
    "params": {
        "name": "image_search",
        "arguments": {"input": {"query": "vacation photo"}}
    }
})
print(json.dumps(resp.json(), indent=2))
```

## Transport Notes

- Only `POST` requests are accepted. `GET` requests return `405 Method Not Allowed`.
- SSE endpoint discovery is not supported; use StreamableHttp transport only.
- Each request must include `Content-Type: application/json`.
