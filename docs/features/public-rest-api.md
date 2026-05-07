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

### Upload Image

- Method: `POST`
- Path: `/api/v1/images`
- Content-Type: `multipart/form-data`

Request form fields:

| Name | Type | Required | Description |
|---|---|---|---|
| `file` | File | Yes | Image file (`PNG`, `JPG`, `JPEG`, `GIF`, `WEBP`) |
| `note` | String | No | User note for the image |

Example:

```bash
curl -X POST https://your-domain.com/api/v1/images \
  -H "Authorization: Bearer vmemo_your_token" \
  -F "file=@/path/to/image.jpg" \
  -F "note=My vacation photo"
```

Success response (`200`):

```json
{
  "data": {
    "id": "e1015cc4-245c-47b9-a86f-50d8874652d0",
    "url": "https://your-domain.com/images/e1015cc4-245c-47b9-a86f-50d8874652d0",
    "note": "My vacation photo",
    "inserted_at": "2026-04-17T07:09:47.519172Z"
  }
}
```

After upload, the system automatically:
- Indexes the image in Typesense for search
- Generates a caption via Moondream AI

### Get Image

- Method: `GET`
- Path: `/api/v1/images/:id`

Example:

```bash
curl -X GET https://your-domain.com/api/v1/images/e1015cc4-245c-47b9-a86f-50d8874652d0 \
  -H "Authorization: Bearer vmemo_your_token"
```

Success response (`200`):

```json
{
  "data": {
    "id": "e1015cc4-245c-47b9-a86f-50d8874652d0",
    "url": "https://your-domain.com/images/e1015cc4-245c-47b9-a86f-50d8874652d0",
    "note": "My vacation photo",
    "inserted_at": "2026-04-17T07:09:47.519172Z"
  }
}
```

### Delete Image

- Method: `DELETE`
- Path: `/api/v1/images/:id`

Example:

```bash
curl -X DELETE https://your-domain.com/api/v1/images/e1015cc4-245c-47b9-a86f-50d8874652d0 \
  -H "Authorization: Bearer vmemo_your_token"
```

Success response (`200`):

```json
{
  "data": {
    "id": "e1015cc4-245c-47b9-a86f-50d8874652d0",
    "message": "Image deleted successfully"
  }
}
```

## Error Format

All API errors follow this shape:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable error message"
  }
}
```

### Error Codes

| HTTP | Code | Meaning |
|---|---|---|
| `400` | `INVALID_FILE` | No file provided, invalid file type, or invalid image format |
| `401` | `UNAUTHORIZED` | Missing, invalid, disabled, or expired token |
| `404` | `PHOTO_NOT_FOUND` | Image not found or not owned by token user |
| `500` | `CREATE_FAILED` | Failed to create image record |
| `500` | `DELETE_FAILED` | Failed to delete image |

## File Constraints

- Allowed formats: `PNG`, `JPG`, `JPEG`, `GIF`, `WEBP`
- Validation: both file extension and file header (magic bytes) are checked
- Files with non-image content (e.g. a `.png` extension on a PDF) are rejected

## Usage Examples

### Upload with note (curl)

```bash
curl -X POST http://localhost:4000/api/v1/images \
  -H "Authorization: Bearer vmemo_fuqOukQ4iBPZhBGFbRBtrf2n9WWlxIATmj_xIfo6eDM" \
  -F "file=@wall-e.png" \
  -F "note=Wall-E robot from Pixar movie"
```

### Upload without note (curl)

```bash
curl -X POST http://localhost:4000/api/v1/images \
  -H "Authorization: Bearer vmemo_your_token" \
  -F "file=@photo.jpg"
```

### Python

```python
import requests

url = "https://your-domain.com/api/v1/images"
headers = {"Authorization": "Bearer vmemo_your_token"}
files = {"file": open("image.jpg", "rb")}
data = {"note": "My photo"}

response = requests.post(url, headers=headers, files=files, data=data)
print(response.json())
```

### JavaScript (fetch)

```javascript
const formData = new FormData();
formData.append("file", fileInput.files[0]);
formData.append("note", "My photo");

const response = await fetch("https://your-domain.com/api/v1/images", {
  method: "POST",
  headers: {
    "Authorization": "Bearer vmemo_your_token"
  },
  body: formData
});
const result = await response.json();
```
