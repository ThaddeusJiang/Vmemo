# 2025-11-25 Moondream Integration

## Background

Vmemo needs to integrate Moondream for automatic image captioning. When a photo is uploaded, the system should call Moondream's caption API to generate a description and store it in Typesense for search.

## Plan

### 1. Docker Compose Configuration

Add Moondream Station service to `docker-compose.yml`:
- Use `vikhyat/moondream-station` Docker image
- Expose port 2020 for REST API access
- Mount volume for model caching

### 2. Moondream API Client

Create `lib/small_sdk/moondream.ex`:
- Implement `caption/2` function to call `/v1/caption` endpoint
- Support base64 image input
- Handle response parsing and error handling
- Make endpoint URL configurable via environment variable

### 3. Integration with Photo Sync Worker

Modify `lib/vmemo/workers/sync_photo_to_typesense.ex`:
- After syncing photo to Typesense, call Moondream caption API
- Update Typesense document with `_gen_description` field
- Handle errors gracefully (don't fail the whole sync if caption fails)

### 4. Configuration

Add environment variables:
- `MOONDREAM_URL` - Moondream Station endpoint (default: `http://localhost:2020/v1`)

## API Reference

Moondream Station REST API:
- Endpoint: `POST /v1/caption`
- Headers: `Content-Type: application/json`
- Body: `{"image_url": "data:image/jpeg;base64,...", "length": "normal", "stream": false}`
- Response: `{"caption": "...", "request_id": "..."}`

## Notes

- Moondream Station runs locally, no API key needed
- Caption generation is async in the Oban worker, won't block photo upload
- Using "normal" length for detailed descriptions
