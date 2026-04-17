# Integration Test Manual: Token, API, MCP

## Overview

End-to-end test scenarios for the complete workflow: token creation, image upload via API and MCP, image metadata modification, and natural language search.

Prerequisites:
- Running Vmemo instance at `http://localhost:4000`
- Logged-in user account
- Test images in `test/support/fixtures/images/`
- Typesense search engine running

## 1. Token Management

### TC-1.1 Create API Token

- Steps:
  1. Navigate to `/tokens`
  2. Click "Create New Token"
  3. Enter name: "Integration Test Token"
  4. Select expiration: "30 days"
  5. Click "Save"
- Expected:
  - Modal shows "Token Created Successfully"
  - Token value starts with `vmemo_`
  - Token format: `vmemo_<43-char-base64url-string>`
- Verify:
  - Navigate to `/tokens`, token appears in list
  - Stats show: Total Tokens = 1, Active Tokens = 1

### TC-1.2 Token Usage Tracking

- Steps:
  - Make several API requests with the token
- Expected:
  - `usage_count` increments per successful token verification
  - `last_used_at` updates to the latest request time
- Verify:
  - Query DB: `Vmemo.Repo.one(Vmemo.Account.ApiToken)` and check `usage_count`

### TC-1.3 Token Expiration Display

- Steps:
  - Check the token list at `/tokens`
- Expected:
  - Expires column shows the calculated expiration date (30 days from creation)

## 2. REST API - Image Upload

### TC-2.1 Upload Image with Note

- Request:
  - `POST /api/v1/images` with Bearer token, file=`wall-e.png`, note="Wall-E robot"
- Expected:
  - Status 200, `status: "success"`
  - Response includes `id`, `url`, `note`, `inserted_at`
- Verify:
  - `GET /api/v1/images/:id` returns the same image data

```bash
curl -X POST http://localhost:4000/api/v1/images \
  -H "Authorization: Bearer vmemo_<token>" \
  -F "file=@test/support/fixtures/images/wall-e.png" \
  -F "note=Wall-E robot from Pixar movie"
```

### TC-2.2 Upload Image without Note

- Request:
  - `POST /api/v1/images` with Bearer token, file only
- Expected:
  - Status 200, `note` field is empty string

### TC-2.3 Upload with Unicode Filename and Note

- Request:
  - `POST /api/v1/images` with file=`正式 small.jpg`, note="正式照片"
- Expected:
  - Status 200, Unicode note preserved correctly

```bash
curl -X POST http://localhost:4000/api/v1/images \
  -H "Authorization: Bearer vmemo_<token>" \
  -F "file=@test/support/fixtures/images/正式 small.jpg" \
  -F "note=正式照片，一张小尺寸的正式照"
```

### TC-2.4 Upload without Auth Token

- Request:
  - `POST /api/v1/images` without Authorization header
- Expected:
  - Status 401, `code: "UNAUTHORIZED"`, `message: "Invalid or missing API token"`

### TC-2.5 Upload Invalid File Type

- Request:
  - `POST /api/v1/images` with a PDF file
- Expected:
  - Status 400, `code: "INVALID_FILE"`, `message: "Invalid file type. Only image files are allowed"`

```bash
curl -X POST http://localhost:4000/api/v1/images \
  -H "Authorization: Bearer vmemo_<token>" \
  -F "file=@test/support/fixtures/images/日本語　＆　００９＿￥＄.pdf"
```

### TC-2.6 Upload without File

- Request:
  - `POST /api/v1/images` with no file field
- Expected:
  - Status 400, `code: "INVALID_FILE"`, `message: "No file provided"`

### TC-2.7 Get Image

- Request:
  - `GET /api/v1/images/:id` with valid image ID
- Expected:
  - Status 200, returns `id`, `url`, `note`, `inserted_at`

### TC-2.8 Delete Image

- Request:
  - `DELETE /api/v1/images/:id` with valid image ID
- Expected:
  - Status 200, `message: "Image deleted successfully"`
- Verify:
  - Subsequent `GET /api/v1/images/:id` returns 404

## 3. MCP Server

### TC-3.1 Initialize Session

- Request:
  - `POST /mcp` with `method: "initialize"`
- Expected:
  - Response includes `protocolVersion: "2024-11-05"`, `serverInfo`, `capabilities`
  - Response header includes `mcp-session-id`

```bash
curl -X POST http://localhost:4000/mcp \
  -H "Authorization: Bearer vmemo_<token>" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
```

### TC-3.2 List Tools

- Request:
  - `POST /mcp` with `method: "tools/list"`
- Expected:
  - Returns `image_search` tool with input schema containing `query`, `similar_image_id`, `page`

### TC-3.3 List Resources

- Request:
  - `POST /mcp` with `method: "resources/list"`
- Expected:
  - Returns 3 resources: `image_url`, `image_html`, `image_data`

### TC-3.4 Search via MCP Tool - English Text

- Request:
  - `tools/call` with `image_search`, query: "Wall-E robot"
- Expected:
  - Returns array of image URLs, first result matches the Wall-E image

### TC-3.5 Search via MCP Tool - Chinese Text

- Request:
  - `tools/call` with `image_search`, query: "正式照片"
- Expected:
  - Returns the Chinese portrait photo URL

### TC-3.6 Reject GET Request

- Request:
  - `GET /mcp`
- Expected:
  - Status 405, `"Method Not Allowed"`, message about StreamableHttp

### TC-3.7 Read Resource (Known Limitation)

- Request:
  - `resources/read` with URI `vmemo://image/<id>/url`
- Expected:
  - Currently returns `"Resource not found"` (AshAi URI template matching bug)
- Status:
  - Known issue. AshAi `find_mcp_resource_by_uri` uses exact string match on URI templates

## 4. Image Metadata Modification

### TC-4.1 Update Note and Caption via LiveView

- Steps:
  1. Navigate to `/images/:id`
  2. Edit the Note textarea
  3. Edit the Caption textarea
  4. Click "Save"
- Expected:
  - Flash message "Saved" appears
  - Save button disappears (form clean)
- Verify:
  - `GET /api/v1/images/:id` returns updated note

### TC-4.2 Update Note and Caption via Ash Resource

- Steps:
  - Call `Image.update(image, %{note: "new note", caption: "new caption"}, actor: user)`
- Expected:
  - Returns `{:ok, updated_image}` with new values
- Verify:
  - `updated_image.note` matches new value
  - `updated_image.caption` matches new value
  - `typesense_status` set to "pending" (re-index triggered)

## 5. Natural Language Search

### TC-5.1 Search by Note Text

- Query:
  - "Wall-E"
- Expected:
  - Returns Wall-E images (matches note field)

### TC-5.2 Search by Caption Text

- Query:
  - "Rubik" (only in caption: "...holding a Rubik's cube...")
- Expected:
  - Returns Wall-E images (matches caption field)

### TC-5.3 Search by Chinese Text

- Query:
  - "正式照片"
- Expected:
  - Returns the Chinese portrait photo

### TC-5.4 Cross-field Search

- Query:
  - "formal portrait" (only in English caption of the Chinese image)
- Expected:
  - Returns the Chinese portrait photo

### TC-5.5 Search by Caption Keywords

- Query:
  - "kill all humans" (in Bender image caption)
- Expected:
  - Returns the Bender/Futurama image

## Test Data

### Fixture Images Used

- `wall-e.png`
  - Size: 4.0 MB
  - Purpose: Standard image upload test
- `kill_all_humans.png`
  - Size: 129 KB
  - Purpose: Image with distinctive content
- `正式 small.jpg`
  - Size: 218 KB
  - Purpose: Unicode filename and note test
- `日本語　＆　００９＿￥＄.pdf`
  - Size: 459 KB
  - Purpose: Invalid file type rejection test

### Test Notes and Captions

- `wall-e.png`
  - Note: Wall-E robot from Pixar movie, a friendly garbage compactor robot
  - Caption: A rusty yellow robot named Wall-E holding a Rubik's cube, from the animated movie Wall-E
- `kill_all_humans.png`
  - Note: Bender Rodriguez from Futurama, a sarcastic bending robot
  - Caption: A cartoon robot character Bender from Futurama TV show holding a sign that reads kill all humans
- `正式 small.jpg`
  - Note: 正式照片，一张小尺寸的正式照
  - Caption: A formal portrait photo of a person in professional attire
