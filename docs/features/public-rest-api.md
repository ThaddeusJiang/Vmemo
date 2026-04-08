# REST API

## Overview

Vmemo provides a REST API for external integrations. Every request must be authenticated with an API token.

- Base URL: `https://your-domain.com/api/v1`
- Version: `v1`
- Authentication: `Authorization: Bearer <token>`

## Authentication

### Bearer Token

Include a valid token in the request header:

```http
Authorization: Bearer vmemo_your_token_here
```

### Token Source

Create tokens in the Vmemo web app at `/tokens`. Tokens are shown only once at creation time.

Token format:

```text
vmemo_<43-char-random-string>
```

## Endpoints

### Upload Photo

- Method: `POST`
- Path: `/api/v1/photos`
- Content-Type: `multipart/form-data`

Request form fields:

| Name | Type | Required | Description |
|---|---|---|---|
| `file` | File | Yes | Image file (`PNG`, `JPG`, `JPEG`, `GIF`, `WEBP`) |
| `note` | String | No | Optional user note |

Example:

```bash
curl -X POST https://your-domain.com/api/v1/photos \
  -H "Authorization: Bearer vmemo_your_token" \
  -F "file=@/path/to/image.jpg" \
  -F "note=My vacation photo"
```

Success response (`200`):

```json
{
  "status": "success",
  "data": {
    "id": "01JKQM8X9Y7Z6W5V4U3T2S1R0P",
    "url": "/storage/v1/<user_id>/photos/20250126_103045_image.jpg",
    "note": "My vacation photo",
    "inserted_at": "2025-01-26T10:30:45Z"
  }
}
```

### Get Photo

- Method: `GET`
- Path: `/api/v1/photos/:id`

Example:

```bash
curl -X GET https://your-domain.com/api/v1/photos/01JKQM8X9Y7Z6W5V4U3T2S1R0P \
  -H "Authorization: Bearer vmemo_your_token"
```

Success response (`200`):

```json
{
  "status": "success",
  "data": {
    "id": "01JKQM8X9Y7Z6W5V4U3T2S1R0P",
    "url": "/storage/v1/user_abc123/photos/20250126_103045_image.jpg",
    "note": "My vacation photo",
    "caption": "A beautiful sunset over the ocean",
    "inserted_at": "2025-01-26T10:30:45Z",
    "updated_at": "2025-01-26T10:31:00Z"
  }
}
```

### Delete Photo

- Method: `DELETE`
- Path: `/api/v1/photos/:id`

Example:

```bash
curl -X DELETE https://your-domain.com/api/v1/photos/01JKQM8X9Y7Z6W5V4U3T2S1R0P \
  -H "Authorization: Bearer vmemo_your_token"
```

Success response (`200`):

```json
{
  "status": "success",
  "message": "Photo deleted successfully"
}
```

## Error Format

All API errors follow this shape:

```json
{
  "status": "error",
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable error message"
  }
}
```

Common status codes:

| HTTP | Meaning |
|---|---|
| `200` | Success |
| `400` | Invalid input |
| `401` | Missing/invalid/expired token |
| `404` | Resource not found |
| `500` | Internal server error |

## File Constraints

- Allowed formats: `PNG`, `JPG`, `JPEG`, `GIF`, `WEBP`
- Max file size: `10MB` (default, configurable)
- Validation: file header/content validation is enforced
